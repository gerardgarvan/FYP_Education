#!/usr/bin/env python3
"""
inventory.py - read-only inventory of a messy folder (ORG-01 .. ORG-04).

Usage (from the repo root):
    python tools/inventory.py --root _inbox --out docs/inventory

Writes:
    <out>/inventory.csv          one row per file, everything we know about it
    <out>/file_map.csv           proposed disposition per file; Gerard edits the
                                 final_disposition / final_dest columns to override
    <out>/inventory_summary.md   duplicates, version families, data files, path references
    <out>/missing_references.md  D-05: references not found in the inventory (three groups)

Never modifies, moves or deletes anything under --root.
Standard library only.
"""
import argparse
import csv
import datetime as dt
import hashlib
import os
import re
from collections import defaultdict

CATEGORIES = {
    "sas_program": {".sas"},
    "r_program":   {".r", ".rmd", ".qmd"},
    "python":      {".py", ".ipynb"},
    "sql":         {".sql"},
    "sas_log":     {".log", ".lst", ".mht"},
    "sas_data":    {".sas7bdat", ".sas7bcat", ".sas7bvew", ".xpt"},
    "spreadsheet": {".xlsx", ".xlsm", ".xls"},
    "delimited":   {".csv", ".tsv", ".dat"},
    "r_data":      {".rds", ".rdata", ".rda"},
    "word":        {".docx", ".doc", ".rtf"},
    "powerpoint":  {".pptx", ".ppt"},
    "pdf":         {".pdf"},
    "image":       {".png", ".jpg", ".jpeg", ".gif", ".svg", ".emf", ".tif", ".tiff", ".bmp"},
    "text":        {".txt", ".md"},
    "project":     {".egp", ".rproj", ".sasproj"},
    "archive":     {".zip", ".7z", ".gz"},
}
DATA_CATEGORIES = {"sas_data", "spreadsheet", "delimited", "r_data"}
CODE_CATEGORIES = {"sas_program", "r_program", "python", "sql"}
DOC_CATEGORIES = {"word", "powerpoint", "pdf", "image", "text"}
TEXT_SCAN = CODE_CATEGORIES | {"sas_log", "text"}

KEYWORDS = [
    "FIBRO", "FIBRO_MASTER", "CLARITY", "CLARITY_CONCEPT", "PRECEDE", "PeCAN",
    "MT_EDUC_GROUP", "MEGA_GROUP", "Edu_Years", "Mortality_1Y", "Died_1yr",
    "Frailty", "ASA", "race_sa2", "Reading", "Literacy", "WRAT", "Health_Lit",
    "logistic", "sgplot", "ggplot",
]

# Absolute path references (drive letters, UNC, /blue, /mnt).
PATH_RE = re.compile(
    r"""([A-Za-z]:\\[^"';\r\n]+|\\\\[^"';\r\n]+|/blue/[^"';\s]+|/mnt/[^"';\s]+|[A-Za-z]:/[^"';\r\n]+)"""
)

# Quoted-string file references for common constructs.
# Each group captures the referenced path/name from INSIDE quotes only.
# out= and outfile= with quotes are captured in OUTFILE_RE below, NOT here.
# bare identifiers (no quotes) are not captured.
REF_RE = re.compile(
    r"""(?xi)
    (?:%include\s+["']([^"';\r\n]+)["'])            # SAS %include "x.sas"
    |(?:datafile\s*=\s*["']([^"';\r\n]+)["'])       # SAS datafile="x.csv"
    |(?:\binfile\s+["']([^"';\r\n]+)["'])           # SAS infile "x.dat"
    |(?:read\.csv\s*\(\s*["']([^"']+)["'])          # R read.csv("x.csv")
    |(?:read_excel\s*\(\s*["']([^"']+)["'])         # R read_excel("x.xlsx")
    |(?:readRDS\s*\(\s*["']([^"']+)["'])            # R readRDS("x.rds")
    |(?:source\s*\(\s*["']([^"']+)["'])             # R source("x.R")
    |(?:\bopen\s*\(\s*["']([^"']+)["'])             # Python open("x.txt")
    """,
    re.IGNORECASE,
)

# Quoted path argument of libname/filename — these are FOLDERS, not file references.
FOLDER_RE = re.compile(
    r"""(?xi)
    (?:libname\s+\w+\s+["']([^"';\r\n]+)["'])      # SAS libname lib "path"
    |(?:filename\s+\w+\s+["']([^"';\r\n]+)["'])    # SAS filename f "path"
    """,
    re.IGNORECASE,
)

# Output file references — quoted outfile= targets; treated as WRITE, excluded from missing check.
OUTFILE_RE = re.compile(
    r"""(?xi)
    (?:\boutfile\s*=\s*["']([^"';\r\n]+)["'])       # SAS outfile="x.csv" (write)
    |(?:\bout\s*=\s*["']([^"';\r\n]+)["'])          # SAS out="x.sas7bdat" (write)
    """,
    re.IGNORECASE,
)

COPY_RE = re.compile(r"\(\d+\)|\bcopy\b|- Copy", re.I)
MONTHS = r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*"

# Macro-variable / dynamic reference pattern (e.g. &root.\x.sas or string concat)
DYNAMIC_RE = re.compile(r"&\w|[|][|]|\+\s*[\"']|[\"']\s*\+")

# Junk file names — defined once here so Plans 02 and 04 can import is_junk().
JUNK_NAMES = {".gitkeep", "Thumbs.db", "desktop.ini", ".DS_Store"}


def is_junk(name):
    """Return True for OS/editor junk files that should be excluded from inventory."""
    low = name.lower()
    return (
        name in JUNK_NAMES
        or low in {n.lower() for n in JUNK_NAMES}
        or name.startswith("~$")
    )


def category(ext):
    for cat, exts in CATEGORIES.items():
        if ext in exts:
            return cat
    return "other"


def family_key(name):
    """Collapse dates, versions, copies and initials so versions of one file group together."""
    stem, ext = os.path.splitext(name.lower())
    s = " " + re.sub(r"[_\-.,]+", " ", stem) + " "
    s = re.sub(r"\(\d+\)", " ", s)
    patterns = [
        r"\bcopy( of)?\b",
        r"\b(19|20)\d{6}\b",
        r"\b\d{1,2} \d{1,2} \d{2,4}\b",
        r"\b" + MONTHS + r"\b( \d{1,2}\b)?",
        r"\b(19|20)\d{2}\b",
        r"\b(v|ver|version) ?\d+\b",
        r"\b(final|draft|new|old|updated|revised|rev\d*|latest|edit\d*|fixed|backup|bak)\b",
        r"\b(gjg|mt|cwg)\b",
    ]
    for p in patterns:
        s = re.sub(p, " ", s)
    s = re.sub(r"\s+", "_", s.strip())
    return (s or stem) + ext


def sha256(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def scan_text(path, cat):
    """Return (keywords, paths_referenced, log_errors) for a text-scannable file.

    paths_referenced entries use prefixes:
      folder:<path>  — libname/filename folder argument (not a file reference)
      out:<path>     — outfile=/out= write target (excluded from missing check)
      (plain)        — read reference (included in missing check)
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            txt = f.read(5_000_000)
    except OSError:
        return "", "", ""
    low = txt.lower()
    kws = [k for k in KEYWORDS if k.lower() in low]

    # 1. Collect folder arguments (libname/filename paths) — these are folders, not file refs.
    folder_set = set()
    for m in FOLDER_RE.finditer(txt):
        val = next((g.strip() for g in m.groups() if g is not None), None)
        if val:
            folder_set.add(val)

    # 2. Collect output (write) targets — excluded from the missing-reference check.
    outfile_set = set()
    for m in OUTFILE_RE.finditer(txt):
        val = next((g.strip() for g in m.groups() if g is not None), None)
        if val:
            outfile_set.add(val)

    # 3. Collect read references from REF_RE (quoted-string only, no bare identifiers).
    read_refs = []
    seen = set()
    for m in REF_RE.finditer(txt):
        val = next((g.strip() for g in m.groups() if g is not None), None)
        if val and val not in seen:
            # Skip if this value is a folder arg or outfile target
            if val in folder_set or val in outfile_set:
                continue
            seen.add(val)
            read_refs.append(val)

    # 4. Collect absolute paths from PATH_RE (both quoted and unquoted).
    #    Drop any that are folder args, outfile targets, or already captured by REF_RE.
    for m in PATH_RE.findall(txt):
        val = m.strip().rstrip(".);,")
        if not val:
            continue
        if val in folder_set or val in outfile_set:
            continue
        if val not in seen:
            seen.add(val)
            read_refs.append(val)

    # Build the combined paths_referenced list with prefixes.
    parts = []
    for f in sorted(folder_set):
        parts.append(f"folder:{f}")
    for o in sorted(outfile_set):
        parts.append(f"out:{o}")
    parts.extend(read_refs)

    errs = ""
    if cat == "sas_log":
        errs = str(sum(1 for line in txt.splitlines() if line.startswith("ERROR")))
    return ";".join(kws), " | ".join(parts), errs


def propose(row):
    cat = row["category"]
    if row["is_dup_copy"] == "Y":
        return "DUPLICATE", "archive/duplicates"
    if cat in DATA_CATEGORIES:
        return "DATA", "archive/data_local"
    if cat == "sas_log":
        return "ARCHIVE", "archive/logs"
    if cat in CODE_CATEGORIES:
        lang = {"sas_program": "sas", "r_program": "R", "python": "python", "sql": "sql"}[cat]
        if row["is_latest_in_family"] == "Y":
            return "KEEP", f"legacy/{lang}"
        return "ARCHIVE", f"archive/old_versions/{lang}"
    if cat in DOC_CATEGORIES:
        if row["is_latest_in_family"] == "Y":
            return "KEEP", "docs/reference"
        return "ARCHIVE", "archive/old_versions/docs"
    return "REVIEW", ""


def _basename(ref):
    """Extract basename from a reference path, handling both / and \\ separators."""
    return os.path.basename(ref.replace("\\", "/").replace("\\", "/"))


def write_missing_references(out_dir, rows):
    """Write docs/inventory/missing_references.md (D-05 output)."""
    # Build case-insensitive name -> count map from inventoried files.
    name_counts = defaultdict(int)
    name_to_paths = defaultdict(list)
    for r in rows:
        key = r["name"].lower()
        name_counts[key] += 1
        name_to_paths[key].append(r["rel_path"])

    # Collect folder refs and read-refs from all rows.
    all_folder_refs = []  # (folder_path, rel_path_of_source)
    all_read_refs = []    # (ref, rel_path_of_source)

    for r in rows:
        pr = r.get("paths_referenced", "")
        if not pr:
            continue
        for entry in pr.split(" | "):
            entry = entry.strip()
            if not entry:
                continue
            if entry.startswith("folder:"):
                all_folder_refs.append((entry[len("folder:"):], r["rel_path"]))
            elif entry.startswith("out:"):
                pass  # output references — excluded from classification
            else:
                all_read_refs.append((entry, r["rel_path"]))

    # Classify read references into groups.
    dynamic = []
    on_p = []
    local_missing = []

    for ref, src_path in all_read_refs:
        # a. Dynamic first — contains macro variable or string concat markers
        if DYNAMIC_RE.search(ref):
            dynamic.append((ref, src_path, None))
            continue

        # Check if resolved by name match
        bn = _basename(ref)
        bn_lower = bn.lower()
        count = name_counts.get(bn_lower, 0)

        if count == 1:
            # Resolved — exactly one match in inventory; not missing.
            continue
        elif count > 1:
            # Ambiguous — multiple files with this name; report as tentative.
            n = name_counts[bn_lower]
            on_p.append((ref, src_path, f"tentative — matches {n} files"))
            continue

        # count == 0: not resolved by name. Classify by path prefix.
        ref_upper = ref.upper()
        if (ref_upper.startswith("P:") or ref_upper.startswith("P:\\") or
                ref_upper.startswith("I:") or ref_upper.startswith("I:\\") or
                ref.startswith("\\\\") or ref.lower().startswith("/blue/") or
                ref.lower().startswith("/mnt/")):
            on_p.append((ref, src_path, None))
        else:
            local_missing.append((ref, src_path, None))

    # Build markdown output.
    L = ["# Missing References", "",
         "Generated by `inventory.py` — D-05 output. References from scanned files that "
         "could not be resolved to an inventoried file.", ""]

    L += ["## Dynamic (can't be resolved)", "",
          "References built from macro variables or string concatenation. A human must inspect these.", ""]
    if dynamic:
        for ref, src, note in dynamic:
            suffix = f" ({note})" if note else ""
            L.append(f"- `{ref}` (from `{src}`){suffix}")
    else:
        L.append("_(none)_")

    L += ["", "## On P: (expected)", "",
          "References to the P: drive or UNC share. Not a gap — these files live on the work PC.", ""]
    if on_p:
        for ref, src, note in on_p:
            suffix = f" ({note})" if note else ""
            L.append(f"- `{ref}` (from `{src}`){suffix}")
    else:
        L.append("_(none)_")

    L += ["", "## Local and missing (real gaps)", "",
          "References to local paths or bare filenames with no matching file in the inventory. "
          "Gerard: check these against SOURCES.md.", ""]
    if local_missing:
        for ref, src, note in local_missing:
            suffix = f" ({note})" if note else ""
            L.append(f"- `{ref}` (from `{src}`){suffix}")
    else:
        L.append("_(none)_")

    L += ["", "## Folders referenced", "",
          "Path arguments of `libname` and `filename` statements. "
          "These are directories, not file references — listed here for completeness.", ""]
    if all_folder_refs:
        seen_folders = set()
        for folder, src in all_folder_refs:
            key = (folder, src)
            if key not in seen_folders:
                seen_folders.add(key)
                L.append(f"- `{folder}` (from `{src}`)")
    else:
        L.append("_(none)_")

    out_path = os.path.join(out_dir, "missing_references.md")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    return out_path


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default="_inbox")
    ap.add_argument("--out", default="docs/inventory")
    a = ap.parse_args()

    root = os.path.abspath(a.root)
    os.makedirs(a.out, exist_ok=True)
    rows = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for fn in sorted(filenames):
            if is_junk(fn):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace("\\", "/")
            ext = os.path.splitext(fn)[1].lower()
            cat = category(ext)
            st = os.stat(full)
            kws, paths, errs = scan_text(full, cat) if cat in TEXT_SCAN else ("", "", "")
            rows.append({
                "id": 0, "rel_path": rel, "name": fn, "ext": ext, "category": cat,
                "size_kb": round(st.st_size / 1024, 1),
                "modified": dt.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M"),
                "_mtime": st.st_mtime, "sha256": sha256(full),
                "family": family_key(fn), "keywords": kws, "paths_referenced": paths,
                "log_errors": errs,
            })

    for i, r in enumerate(rows, 1):
        r["id"] = i

    # Exact duplicates: canonical = shortest path, then newest
    by_hash = defaultdict(list)
    for r in rows:
        by_hash[r["sha256"]].append(r)
    g = 0
    for members in by_hash.values():
        if len(members) > 1:
            g += 1
            members.sort(key=lambda r: (bool(COPY_RE.search(r["name"])), len(r["rel_path"]), -r["_mtime"]))
            for j, r in enumerate(members):
                r["dup_group"] = f"D{g:03d}"
                r["is_dup_copy"] = "N" if j == 0 else "Y"
                r["dup_of"] = "" if j == 0 else members[0]["rel_path"]
    for r in rows:
        r.setdefault("dup_group", "")
        r.setdefault("is_dup_copy", "N")
        r.setdefault("dup_of", "")

    # Version families among canonical copies: latest = newest modified
    fam = defaultdict(list)
    for r in rows:
        if r["is_dup_copy"] == "N":
            fam[r["family"]].append(r)
    for members in fam.values():
        members.sort(key=lambda r: -r["_mtime"])
        for j, r in enumerate(members):
            r["family_size"] = len(members)
            r["is_latest_in_family"] = "Y" if j == 0 else "N"
    for r in rows:
        r.setdefault("family_size", "")
        r.setdefault("is_latest_in_family", "")

    for r in rows:
        r["data_flag"] = "Y" if r["category"] in DATA_CATEGORIES else ""
        r["proposed_disposition"], r["proposed_dest"] = propose(r)

    inv_cols = ["id", "rel_path", "name", "ext", "category", "size_kb", "modified", "sha256",
                "dup_group", "is_dup_copy", "dup_of", "family", "family_size", "is_latest_in_family",
                "data_flag", "keywords", "paths_referenced", "log_errors",
                "proposed_disposition", "proposed_dest"]
    with open(os.path.join(a.out, "inventory.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=inv_cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

    map_cols = ["id", "rel_path", "category", "proposed_disposition", "proposed_dest",
                "final_disposition", "final_dest", "notes"]
    with open(os.path.join(a.out, "file_map.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=map_cols, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({**r, "final_disposition": "", "final_dest": "", "notes": ""})

    # Summary
    L = [f"# Inventory summary", "",
         f"Root: `{a.root}` · scanned {dt.datetime.now():%Y-%m-%d %H:%M} · **{len(rows)} files**", ""]
    cnt = defaultdict(int)
    for r in rows:
        cnt[r["category"]] += 1
    L += ["## By category", "", "| Category | Files |", "|---|---|"]
    L += [f"| {k} | {v} |" for k, v in sorted(cnt.items(), key=lambda kv: -kv[1])]
    disp = defaultdict(int)
    for r in rows:
        disp[r["proposed_disposition"]] += 1
    L += ["", "## Proposed dispositions", "", "| Disposition | Files |", "|---|---|"]
    L += [f"| {k} | {v} |" for k, v in sorted(disp.items())]

    dups = defaultdict(list)
    for r in rows:
        if r["dup_group"]:
            dups[r["dup_group"]].append(r)
    L += ["", f"## Exact duplicates ({len(dups)} groups)", ""]
    for gname, members in sorted(dups.items()):
        members.sort(key=lambda r: r["is_dup_copy"])
        L.append(f"- **{gname}** keep `{members[0]['rel_path']}`; copies: " +
                 ", ".join(f"`{m['rel_path']}`" for m in members[1:]))

    fams = [(k, v) for k, v in fam.items() if len(v) > 1]
    L += ["", f"## Version families ({len(fams)})", ""]
    for k, members in sorted(fams):
        L.append(f"- **{k}** — latest `{members[0]['rel_path']}` ({members[0]['modified']}); older: " +
                 ", ".join(f"`{m['rel_path']}` ({m['modified']})" for m in members[1:]))

    data = [r for r in rows if r["data_flag"]]
    L += ["", f"## Data files — never committed ({len(data)})", ""]
    L += [f"- `{r['rel_path']}` ({r['size_kb']} KB)" for r in data]

    refs = [r for r in rows if r["paths_referenced"]]
    L += ["", f"## Files that reference paths ({len(refs)})", ""]
    L += [f"- `{r['rel_path']}`: {r['paths_referenced']}" for r in refs]

    logs = [r for r in rows if r["log_errors"] not in ("", "0")]
    if logs:
        L += ["", "## Logs with ERROR lines", ""]
        L += [f"- `{r['rel_path']}`: {r['log_errors']} ERROR lines" for r in logs]

    review = [r for r in rows if r["proposed_disposition"] == "REVIEW"]
    L += ["", f"## Needs a decision ({len(review)})", ""]
    L += [f"- `{r['rel_path']}` ({r['category']})" for r in review]

    with open(os.path.join(a.out, "inventory_summary.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")

    # D-05: Write missing_references.md
    mr_path = write_missing_references(a.out, rows)

    print(f"{len(rows)} files inventoried -> {a.out}/inventory.csv, file_map.csv, "
          f"inventory_summary.md, {mr_path}")


if __name__ == "__main__":
    main()
