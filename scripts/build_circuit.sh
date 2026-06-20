#!/usr/bin/env bash
# ============================================================================
# build_circuit.sh — full Groth16 pipeline for ONE Veritas circuit
# ============================================================================
# Usage: ./scripts/build_circuit.sh <circuit_name> <ptau_power>
#   <circuit_name> : trivial | age_gte | credential_age   (dir under circuits/)
#   <ptau_power>    : log2(max constraints). e.g. 4, 12, 16
#
# Produces, under circuits/<name>/build/:
#   <name>.r1cs, <name>_js/<name>.wasm  (compiled circuit)
#   verification_key.json, <name>_final.zkey  (Groth16 proving key)
# Reuses a shared powers-of-tau file at ptau/ptau_<power>.ptau (built once).
set -euo pipefail

NAME="${1:?circuit name required (trivial|age_gte|credential_age)}"
POWER="${2:?ptau power required (e.g. 4, 12, 16)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CIRC_DIR="$ROOT/circuits/$NAME"
BUILD_DIR="$CIRC_DIR/build"
PTAU_DIR="$ROOT/ptau"
PTAU="$PTAU_DIR/ptau_${POWER}.ptau"

mkdir -p "$BUILD_DIR" "$PTAU_DIR"

# Locate the .circom source. trivial uses preimage.circom, others use <name>.circom
if [ -f "$CIRC_DIR/preimage.circom" ]; then
    SRC="$CIRC_DIR/preimage.circom"
    BASE="preimage"
else
    SRC="$CIRC_DIR/$NAME.circom"
    BASE="$NAME"
fi

echo "▶ [$NAME] circuit src : $SRC"

# ---- 0. shared powers-of-tau (phase 1) ---- build once per power
if [ ! -f "$PTAU" ]; then
    echo "▶ [$NAME] building shared powers-of-tau (power=$POWER) -> $PTAU"
    snarkjs powersoftau new bn254 "$POWER" "$PTAU_DIR/ptau_0000.ptau" -v >/dev/null
    snarkjs powersoftau contribute "$PTAU_DIR/ptau_0000.ptau" "$PTAU_DIR/ptau_0001.ptau" \
        --name="veritas-contrib-1" -v -e="veritas-zk $(date +%s)" >/dev/null
    snarkjs powersoftau prepare phase2 "$PTAU_DIR/ptau_0001.ptau" "$PTAU" -v >/dev/null
    rm -f "$PTAU_DIR/ptau_0000.ptau" "$PTAU_DIR/ptau_0001.ptau"
    echo "  ✓ powers-of-tau ready"
else
    echo "▶ [$NAME] reusing shared powers-of-tau $PTAU"
fi

# ---- 1. compile ----
echo "▶ [$NAME] compiling circuit (circom)"
circom "$SRC" --r1cs --wasm --sym -c -o "$BUILD_DIR" 2>&1 | sed 's/^/    /'
R1CS="$BUILD_DIR/$BASE.r1cs"
WASM="$BUILD_DIR/${BASE}_js/${BASE}.wasm"
ZKEY0="$BUILD_DIR/${BASE}_0000.zkey"
ZKEY="$BUILD_DIR/${BASE}_final.zkey"

# ---- 2. R1CS stats ----
echo "▶ [$NAME] R1CS constraints:"
snarkjs r1cs info "$R1CS" 2>/dev/null | grep -E "Constraints|Variables|Private Inputs|Public Inputs|Outputs" | sed 's/^/    /'

# ---- 3. Groth16 phase-2 trusted setup (circuit-specific) ----
echo "▶ [$NAME] Groth16 setup (phase 2)"
snarkjs groth16 setup "$R1CS" "$PTAU" "$ZKEY0" >/dev/null
snarkjs zkey contribute "$ZKEY0" "$ZKEY" --name="veritas" -v \
    -e="veritas-zk $(date +%s)" >/dev/null
rm -f "$ZKEY0"

# ---- 4. export verification key ----
snarkjs zkey export verificationkey "$ZKEY" "$BUILD_DIR/verification_key.json" >/dev/null
echo "  ✓ verification_key.json exported"

echo "✓ [$NAME] build complete"
echo "    proving key : $ZKEY"
echo "    wasm        : $WASM"
echo "    vk          : $BUILD_DIR/verification_key.json"
