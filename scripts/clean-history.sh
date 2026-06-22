#!/bin/bash
# Removes large circom build artifacts from veritas-zk git history
#
# The repo is 101MB due to .r1cs/.zkey/.wasm/.ptau files committed in history.
# Run this to shrink it to <5MB.
#
# PREREQUISITES:
#   pip install git-filter-repo
#   Backup: cp -r veritas-zk veritas-zk-backup
#
# USAGE:
#   cd veritas-zk
#   bash scripts/clean-history.sh
#
# After: git push --force --all  (DESTRUCTIVE — rewrites all history!)
# Then verify: cargo test still passes

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

echo "=== veritas-zk History Cleanup ==="
echo "Current size:"
du -sh .git

# Check for git-filter-repo
if ! command -v git-filter-repo &>/dev/null; then
    echo "ERROR: git-filter-repo not found. Install with:"
    echo "  pip install git-filter-repo"
    exit 1
fi

# Count large files
echo ""
echo "Large files in history (>1MB):"
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  awk '/^blob/ {if ($3 > 1048576) print $3/1048576 "MB", $4}' | \
  sort -rn | head -20

echo ""
echo "Removing circom build artifacts from history..."
git filter-repo --invert-paths \
  --path-glob 'target/*.r1cs' \
  --path-glob 'target/*.zkey' \
  --path-glob 'target/*.wasm' \
  --path-glob 'target/*.ptau' \
  --path-glob 'target/*.cs' \
  --path-glob 'build/*' \
  --path-glob '*.r1cs' \
  --path-glob '*.zkey' \
  --force

echo ""
echo "New size:"
du -sh .git

echo ""
echo "=== DONE ==="
echo "⚠️  Git history has been rewritten!"
echo ""
echo "Next steps:"
echo "  1. Verify tests: cargo test"
echo "  2. Force push: git push --force --all"
echo "  3. Verify CI: check GitHub Actions"
