# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Overview

**Veritas** is a privacy-preserving ZK credential verifier on Stellar / Soroban. An issuer signs a
credential (KYC claim) with BabyJubJub EdDSA-Poseidon; a holder generates a **Groth16** proof of a
*derived predicate* (e.g. "age ≥ 18", "country ∈ allow-set", "credential is valid & mine") off-chain;
a Soroban smart contract verifies the proof **on-chain** using a real BN254 pairing implemented in
WASM. The underlying document (DOB, country, identity) is never revealed. Built for the
**Stellar Hacks: Real-World ZK** hackathon.

The same verifier circuit can gate compliant transfers, age-gated faucets, or confidential tokens.

## Tech Stack

- **Circom 2.x** — circuit DSL (`circuits/`)
- **snarkjs 0.7.x** — Groth16 trusted setup, proof generation & off-chain verification
- **circomlib / circomlibjs** — Poseidon hash, BabyJubJub EdDSA primitives (iden3)
- **Rust** + `ark-bn254` — Soroban verifier contract that performs the BN254 pairing inside WASM
  (Stellar has no BN254 precompile, so the miller-loop / final-exponentiation lives in the contract)
- **Soroban** (`stellar` CLI, `wasm32v1-none` target) — on-chain deployment target
- **Node.js 18+** — orchestrates proving/encoding services and demo scripts
- **Python** — alternative toolchain in `python/` (issuer / witness / proof / verify)
- **Dockerfile** — reproducible environment bundling circom + snarkjs + Rust + stellar CLI

## Commands

```bash
# Setup (one-time)
rustup target add wasm32v1-none
npm install

# Full end-to-end demo (compiles circuits, trusted setup, real Groth16 proofs,
# byte-encoding, contract compile, on-chain sandbox verify)
bash scripts/demo.sh

# Just the circuits
node scripts/gen_test_inputs.js        # issuer signs demo credentials
bash scripts/verify_all.sh             # setup + prove + off-chain verify
node scripts/proof_to_bytes.js AgeGte  # → proof.bin / public.bin / vk.bin

# Issuer / prover services
node services/issuer/issue.js 23 18
node services/prover/prove.js ValidOwner

# On-chain verifier tests (6 tests, all must pass)
cd soroban/contracts/veritas-verifier && cargo test

# Deploy to Stellar Testnet
export STELLAR_ADMIN_SECRET="<your testnet secret key>"
bash scripts/deploy_testnet.sh
```

## Architecture (key files)

```
circuits/
  AgeGte.circom              age ≥ threshold from private DOB
  ValidOwner.circom          issuer-signed + owned → emits double-spend nullifier
  JurisdictionAllowed.circom Poseidon Merkle membership (country ∈ allow-set)
  CredentialAge.circom       flagship: combines the above
  lib/                       circomlib primitives (vendored)
  <circuit>/                 per-circuit build output (.r1cs / .wasm / .zkey) — see below
soroban/contracts/veritas-verifier/
  src/groth16.rs             BN254 pairing core (miller-loop + final-exponentiation) — unit-tested against real snarkjs proofs
  src/contract.rs            verify / verify_for / verify_credential / claim_faucet + admin setters
  src/spec.rs                per-circuit public-input layout & vkey encoding
  src/lib.rs                 module wiring
  tests/verify_real.rs       verifies REAL snarkjs proofs; rejects tampered/cross-circuit proofs
  tests/sandbox.rs           deploys in Soroban sandbox, verifies on-chain
services/issuer/issue.js     off-chain attester (BabyJub EdDSA-Poseidon signing)
services/prover/prove.js     off-chain prover (witness + Groth16 proof + byte encoding)
scripts/
  gen_test_inputs.js   demo credential signing
  verify_all.sh        full setup + prove + off-chain verify
  proof_to_bytes.js    encode proof/public/vk into the on-chain byte format
  build_circuit.sh     per-circuit compile + trusted-setup driver
  demo.sh              the full demo walkthrough
  deploy_testnet.sh    testnet deploy + install vkey + submit a real proof
  zk_helpers.js        shared JS helpers
python/                alternate Python toolchain (issuer/witness/proof/verify/demo.sh)
```

### Byte encoding (no length prefixes, big-endian)
- `proof_bytes` (256 B): `A.x A.y | B.x.c0 B.x.c1 B.y.c0 B.y.c1 | C.x C.y`
- `public_inputs_bytes`: `nPublic × 32 B` (snarkjs `public.json` order: outputs then inputs)
- `vk_bytes`: `α(2) β(4) γ(4) δ(4) nPublic(1) IC[(n+1)×2]`

## Important Notes

- **Build artifacts, not source.** Anything under `circuits/<circuit>/` — `.r1cs`, compiled
  `<circuit>.wasm`, `.zkey` (proving/verifying keys), `.vkey.json`, witness `.wtns`, and the
  `ptau/` powers-of-tau file — is **regenerated** by `scripts/build_circuit.sh` /
  `scripts/verify_all.sh` / `scripts/demo.sh`. Do **not** hand-edit them. If they drift or go stale,
  delete the affected `<circuit>/` folder (or `ptau/`) and re-run the build scripts.
- **Trusted setup is hackathon-grade.** The `ptau/` file uses a single public contribution — fine
  for a demo, **not** for production. Documented honestly in the README; do not silently strengthen it.
- **Demo keys are throwaway.** The issuer keypair in `services/issuer/` is generated fresh each run
  and is explicitly marked `DO NOT USE IN PROD`. Never reuse it or commit a real production key.
- **Stellar has no BN254 precompile.** The full pairing lives in `src/groth16.rs` and compiles to
  ~73 KB of WASM. Gas cost on testnet is real and non-trivial; keep that in mind when iterating.
- **No secrets, no mainnet.** No private keys or API keys are committed. The repo touches **no**
  mainnet funds and does **not** submit to any hackathon portal.
- **DoraHacks submission ready: DORAHACKS_SUBMISSION.md**
- **Before reporting "done":** run `cd soroban/contracts/veritas-verifier && cargo test` — all 6
  tests (`verify_real.rs` + `sandbox.rs`) must pass. `bash scripts/demo.sh` is the canonical
  end-to-end smoke test.
