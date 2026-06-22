# Git History Size Report — veritas-zk

Generated for HICLAW_MANAGER to assess repo bloat before cleanup/submission.

## Summary

| Metric | Value |
|---|---|
| `.git` total size | **2.6 MB** |
| Blobs > 1 MB in history | **1** |
| Largest blob | **4.63 MB** |

Verdict: **Lean repo.** No history rewrite needed. The single large blob is small enough that the overall pack is well under any platform push limits.

## Large Blobs (> 1 MB)

Scanned all objects across the full history (`git rev-list --objects --all`):

| Size | Path |
|---|---|
| 4.63272 MB | `circuits/age_gte/build/age_gte_cpp/age_gte.cpp` |

Only one blob exceeds 1 MB. It's a generated C++ artifact inside a `build/` directory — a prime candidate for `.gitignore` going forward, but harmless in the current history.

## Notes

- The 4.6 MB uncompressed blob compresses/deltifies down to fit within the 2.6 MB total `.git` pack, so there is significant redundancy (likely multiple revisions of the same generated file).
- No action required for submission. If you want to slim the repo further later, `git filter-repo` on `circuits/**/build/` would remove the generated artifacts, but it's optional.
