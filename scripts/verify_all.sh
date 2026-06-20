#!/usr/bin/env bash
# End-to-end Groth16 build/prove/verify for the three Veritas circuits.
# Uses the bundled public powers-of-tau (hackathon-grade trusted setup).
set -e
cd "$(dirname "$0")/../circuits"

PTAU=../ptau/ptau_16.ptau
PTAU_DIR=../ptau
mkdir -p build/zkeys "$PTAU_DIR"

# ---- generate the shared powers-of-tau if missing (cold-clone reproducibility)
#      — hackathon-grade single-contribution ceremony.
if [ ! -f "$PTAU" ]; then
  echo "▶ generating shared powers-of-tau (power=16) -> $PTAU"
  snarkjs powersoftau new bn254 16 "$PTAU_DIR/ptau_0000.ptau" >/dev/null 2>&1
  snarkjs powersoftau contribute "$PTAU_DIR/ptau_0000.ptau" "$PTAU_DIR/ptau_0001.ptau" \
      --name="veritas-contrib-1" -e="veritas-zk $(date +%s)" >/dev/null 2>&1
  snarkjs powersoftau prepare phase2 "$PTAU_DIR/ptau_0001.ptau" "$PTAU" >/dev/null 2>&1
  rm -f "$PTAU_DIR/ptau_0000.ptau" "$PTAU_DIR/ptau_0001.ptau"
  echo "  ✓ powers-of-tau ready"
fi

for C in AgeGte JurisdictionAllowed ValidOwner; do
  echo "================ $C ================"
  snarkjs groth16 setup    build/$C.r1cs "$PTAU"                 build/zkeys/${C}_0000.zkey >/dev/null 2>&1 && echo "[1/4] setup ok"
  snarkjs zkey contribute  build/zkeys/${C}_0000.zkey build/zkeys/${C}_final.zkey --name="veritas-demo" -v -e="$(date +%s)$RANDOM" >/dev/null 2>&1 && echo "[2/4] contribute ok"
  snarkjs zkey export verificationkey build/zkeys/${C}_final.zkey build/zkeys/${C}_vkey.json >/dev/null 2>&1 && echo "[3/4] vkey ok"
  snarkjs groth16 prove    build/zkeys/${C}_final.zkey build/${C}_js/witness.wtns build/zkeys/${C}_proof.json build/zkeys/${C}_public.json >/dev/null 2>&1 && echo "[4/4] prove ok"
  echo "--- verify ---"
  snarkjs groth16 verify build/zkeys/${C}_vkey.json build/zkeys/${C}_public.json build/zkeys/${C}_proof.json 2>&1 | tail -2
  echo "--- public outputs ($C) ---"
  cat build/zkeys/${C}_public.json
  echo ""
  echo ""
done
