---
phase: 1
slug: inventory-triage
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-28
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest (Python) |
| **Config file** | none — tools are standalone scripts |
| **Quick run command** | `python tools/check_paths.py` |
| **Full suite command** | `python tools/check_paths.py && python -m pytest tools/ -q 2>/dev/null` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python tools/check_paths.py`
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | ORG-01 | manual | `python tools/inventory.py --root _inbox --out docs/inventory` exits 0 | ✅ | ⬜ pending |
| 1-01-02 | 01 | 2 | ORG-02 | manual | `test -f docs/inventory/file_map.csv` | ✅ | ⬜ pending |
| 1-01-03 | 01 | 3 | ORG-03 | manual | `grep -c REVIEW docs/inventory/file_map.csv` returns 0 | ✅ | ⬜ pending |
| 1-01-04 | 01 | 4 | ORG-04 | manual | `python tools/apply_file_map.py` exits 0 (dry run) | ✅ | ⬜ pending |
| 1-01-05 | 01 | 4 | ORG-05 | manual | `python tools/apply_file_map.py --apply` exits 0; `moves_log.csv` row count matches moved files | ✅ | ⬜ pending |
| 1-01-06 | 01 | 5 | ORG-06 | automated | `git status --porcelain \| grep -vE "^\?\? _inbox\|^\?\? archive"` returns empty | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tools/inventory.py` — extensions for D-05 (regex patterns for cross-file refs, missing_references.md)
- [ ] `tools/apply_file_map.py` — extensions for D-19 (SHA-256 verify, per-move log, resumability)

*These are tool extension tasks, not new infrastructure. Existing scripts are the baseline.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gerard approves file_map.csv | ORG-05 | Human gate — requires domain judgment | Gerard reviews REVIEW rows, sets final_disposition; no REVIEW rows remain |
| Data files not staged | ORG-06 | Git behavior | `git status` shows no .xlsx/.csv/.sas7bdat/.rds in staged area |
| _inbox empty after apply | ORG-04 | Filesystem state | `ls _inbox/` shows only .gitkeep after --apply |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
