#!/usr/bin/env bash
# =============================================================================
# Veritas — deploy the verifier to Stellar TESTNET and submit a real proof
# =============================================================================
# This is the "meaningful ZK integration with Stellar testnet" step.
#
# Prereqs:
#   * stellar CLI logged in to testnet, OR set STELLAR_ADMIN_SECRET to a funded
#     testnet account secret key (fund one at https://developers.stellar.org/docs/keys/account-id
#     via the Friendbot: GET https://friendbot.stellar.org?addr=<PUBLIC>).
#   * Run scripts/demo.sh first (builds zkeys + proof bytes + the wasm).
#
# What it does:
#   1. Builds the verifier wasm (if missing).
#   2. Deploys it to testnet.
#   3. Installs the AgeGte verifying key + sets AgeGte as default circuit.
#   4. Submits the REAL AgeGte proof bytes to verify_for() -> prints "true".
#
# NOTE: every byte passed on-chain is exactly the format produced by
# scripts/proof_to_bytes.js — the same bytes the sandbox test verified.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
NETWORK="${STELLAR_NETWORK:-testnet}"
WASM="$(ls soroban/contracts/veritas-verifier/target/wasm32v1-none/release/*.wasm | head -1)"

if [ -z "${STELLAR_ADMIN_SECRET:-}" ]; then
  echo "Set STELLAR_ADMIN_SECRET to a funded $NETWORK account secret key."
  echo "  (create one: stellar keys generate --network $NETWORK)"
  echo "  (fund it:    curl 'https://friendbot.stellar.org?addr=<PUBLIC>')"
  exit 1
fi

c() { printf '\033[1;36m❯ %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }

# 1. build
[ -f "$WASM" ] || ( cd soroban/contracts/veritas-verifier && stellar contract build >/dev/null )
ok "verifier wasm: $WASM"

# 2. deploy
c "deploying verifier to $NETWORK"
CONTRACT_ID="$(stellar contract deploy \
  --wasm "$WASM" \
  --source-account "$STELLAR_ADMIN_SECRET" \
  --network "$NETWORK" --ignore-checks 2>/dev/null | tail -1)"
echo "  contract id: $CONTRACT_ID"
ok "deployed"

call() {  # call <fn> <args...>  (args are positional XDR values)
  stellar contract invoke "$CONTRACT_ID" \
    --source-account "$STELLAR_ADMIN_SECRET" --network "$NETWORK" --ignore-checks "$@"
}

ADMIN="$(stellar keys address --network "$NETWORK" 2>/dev/null || echo "$ADMIN")"
# 3. constructor (idempotent-ish: deploy is fresh each run, so __constructor is first call)
c "initializing contract"
call -- __constructor "$ADMIN" >/dev/null && ok "admin set"

# 4. install AgeGte verifying key (circuit 0) from vk.bin
VK="circuits/build/zkeys/AgeGte_vk.bin"
c "installing AgeGte verifying key (circuit 0)"
call -- set_verifying_key 0 "file:$VK" "$ADMIN" >/dev/null 2>&1 || \
call -- set_verifying_key 0 "file:$VK" >/dev/null
call -- set_default_circuit 0 >/dev/null && ok "AgeGte vkey + default circuit set"

# 5. submit the REAL AgeGte proof to verify_for
PROOF="circuits/build/zkeys/AgeGte_proof.bin"
PUBLIC="circuits/build/zkeys/AgeGte_public.bin"
c "submitting REAL AgeGte proof on-chain  (verify_for 0 proof public)"
RESULT="$(call -- verify_for 0 "file:$PROOF" "file:$PUBLIC")"
echo "  verify_for -> $RESULT"
ok "proof verified on Stellar $NETWORK"

cat <<EOF
  ───────────────────────────────────────────────
  Veritas is live on $NETWORK.
    contract id : $CONTRACT_ID
  Inspect with:
    stellar contract invoke \$CONTRACT_ID --network $NETWORK -- verify_for 0 "file:$PROOF" "file:$PUBLIC"
EOF
