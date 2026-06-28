#!/usr/bin/env bash
# Build Groth16 artifacts (zkey/vkey/proof/public) for all 3 Veritas circuits.
# Designed to run in the background; logs every step so progress is visible.
set -uo pipefail
cd "$(dirname "$0")/../circuits"

PTAU=../ptau/ptau_16.ptau
ZKEYS=build/zkeys
mkdir -p "$ZKEYS"

for C in AgeGte JurisdictionAllowed ValidOwner; do
  echo "==================== $C ===================="
  date +%T

  echo "[1/5] groth16 setup"
  if ! npx snarkjs groth16 setup build/$C.r1cs "$PTAU" "$ZKEYS/${C}_0000.zkey"; then
    echo "SETUP_FAILED $C"; exit 11
  fi

  echo "[2/5] zkey contribute"
  if ! npx snarkjs zkey contribute "$ZKEYS/${C}_0000.zkey" "$ZKEYS/${C}_final.zkey" \
        --name="veritas-demo" -v -e="$(date +%s)$RANDOM"; then
    echo "CONTRIB_FAILED $C"; exit 12
  fi
  rm -f "$ZKEYS/${C}_0000.zkey"

  echo "[3/5] export verificationkey"
  if ! npx snarkjs zkey export verificationkey "$ZKEYS/${C}_final.zkey" "$ZKEYS/${C}_vkey.json"; then
    echo "VKEY_FAILED $C"; exit 13
  fi

  echo "[4/5] groth16 prove"
  if ! npx snarkjs groth16 prove "$ZKEYS/${C}_final.zkey" "build/${C}_js/witness.wtns" \
        "$ZKEYS/${C}_proof.json" "$ZKEYS/${C}_public.json"; then
    echo "PROVE_FAILED $C"; exit 14
  fi

  echo "[5/5] groth16 verify"
  npx snarkjs groth16 verify "$ZKEYS/${C}_vkey.json" "$ZKEYS/${C}_public.json" "$ZKEYS/${C}_proof.json" || true
  echo "--- public ($C) ---"
  cat "$ZKEYS/${C}_public.json"
  echo "DONE_CIRCUIT $C"
  date +%T
done
echo "ALL_CIRCUITS_DONE"
