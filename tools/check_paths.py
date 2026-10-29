#!/usr/bin/env python3
"""
check_paths.py - fail if any pipeline program hard-codes a path (CFG-03).

Allowed:  sas/00_config.sas, R/00_config.R, and the standard first line of each
          SAS program:  %let proj_root = C:\\FYP_Education;
Checked:  sas/*.sas, R/*.R, *.cmd is exempt (it sets the SAS executable path).

Usage: python tools/check_paths.py     (exit 0 = clean)
"""
import glob
import re
import sys

ALLOWED_FILES = {"sas/00_config.sas", "R/00_config.R"}
ALLOWED_LINE = re.compile(r"^\s*%let\s+proj_root\s*=", re.I)
PATTERN = re.compile(r"""(["'\s=(]|^)([A-Za-z]:[\\/]|\\\\[A-Za-z0-9]|/blue/|/mnt/|/home/)""")

bad = []
for f in sorted(glob.glob("sas/*.sas") + glob.glob("R/*.R")):
    f = f.replace("\\", "/")
    if f in ALLOWED_FILES:
        continue
    with open(f, encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            if ALLOWED_LINE.match(line):
                continue
            if PATTERN.search(line):
                bad.append(f"{f}:{n}: {line.strip()}")

if bad:
    print("Hard-coded paths found (move them into 00_config):")
    print("\n".join("  " + b for b in bad))
    sys.exit(1)
print("check_paths: OK")
