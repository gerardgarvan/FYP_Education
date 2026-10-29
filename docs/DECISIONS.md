# Decisions

| ID | Date | Decision | Rationale | By |
|----|------|----------|-----------|----|
| D-01 | 2026-10-28 | Programs live in the git repo on the work PC's local drive (`C:\FYP_Education`); every input and output lives on `P:\PeCAN Research\06 Individual Folders\Mackenzie Topper` | Gerard's request; P: is the shared source of truth | Gerard |
| D-02 | 2026-10-28 | The git repo is never placed on P: | Git index corruption on P: in the master-merge project | Gerard |
| D-03 | 2026-10-28 | Pipeline outputs go to a `FYP_Education\` subfolder of Mackenzie's folder (`sasdata`, `exports`, `tables`, `figures`, `qc`, `logs`) | Keeps her folder root clean; whole output tree can be cleared and rebuilt | Proposed |
| D-04 | 2026-10-28 | Organizing the mess: copy into `_inbox/` → inventory → approved file map → move; nothing deleted | The mess may hold the only copy of something | Proposed |
| D-05 | 2026-10-28 | No data, PHI or Office binaries in the repo (`.gitignore`) | Repo syncs through a git remote | Proposed |
| D-06 | 2026-10-28 | I:\ and P:\ are the same share under different drive letters; repo programs use P:\ only. Phase 2 rewrites legacy I:\ paths to the 00_config.sas macro variables. Use `net use` on the work PC to confirm both letters map to the same folder level before rewriting. | Six legacy SAS programs reference I:\ (older drive-letter mapping for the same PeCAN share). These were classified as "Local and missing" until this decision; they are now correctly classified as "On P: (expected)". | Gerard |
