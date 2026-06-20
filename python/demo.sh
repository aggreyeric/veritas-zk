#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== Veritas ZK Demo ==="
echo "Step 1: Generate signed credential"
python3 "$DIR/issuer.py"
echo "Step 2: Generate witnesses"
python3 "$DIR/witness_gen.py"
echo "Step 3: Generate proofs"
python3 "$DIR/proof_gen.py"
echo "Step 4: Verify proofs"
python3 "$DIR/verify.py"
echo "=== Demo complete ==="
