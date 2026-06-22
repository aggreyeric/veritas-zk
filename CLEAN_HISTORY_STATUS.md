# Veritas ZK — Clean History Status

Check performed on `scripts/clean-history.sh`.

## Syntax Check

```
bash -n scripts/clean-history.sh && echo "SYNTAX OK" || echo "SYNTAX ERROR"
```

**Result:** ✅ **SYNTAX OK** — the script parses without shell syntax errors.

## Prerequisite: `git-filter-repo`

```
which git-filter-repo 2>/dev/null || pip3 show git-filter-repo 2>/dev/null | head -3 || echo "NOT INSTALLED"
```

**Result:** ❌ **NOT INSTALLED** — `git-filter-repo` is not present on this machine. The script will exit early with an error if run as-is (it self-checks for the binary).

## How to Install

```bash
pip install git-filter-repo
```

Verify after installing:

```bash
which git-filter-repo
git filter-repo --version
```

## How to Run the Cleanup Safely

The script rewrites git history (destructive). Recommended sequence:

1. **Back up the repo first** (history rewrite is irreversible):
   ```bash
   cp -r /Users/eric/hiclaw_manager/builds/veritas-zk /Users/eric/hiclaw_manager/builds/veritas-zk-backup
   ```
2. **Install the dependency:**
   ```bash
   pip install git-filter-repo
   ```
3. **Run the script:**
   ```bash
   cd /Users/eric/hiclaw_manager/builds/veritas-zk
   bash scripts/clean-history.sh
   ```
4. **Verify tests still pass:**
   ```bash
   cargo test
   ```
5. **Force-push the rewritten history** (coordinate with any collaborators):
   ```bash
   git push --force --all
   git push --force --tags
   ```

## Summary

| Check              | Status |
| ------------------ | ------ |
| Script syntax      | ✅ OK  |
| `git-filter-repo`  | ❌ Not installed |
| Safe to run        | ⏳ Blocked — install `git-filter-repo` and back up repo first |
