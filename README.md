![circom](https://img.shields.io/badge/circom-circuits-blue) ![Groth16](https://img.shields.io/badge/zk-Groth16-brightgreen) ![Soroban](https://img.shields.io/badge/blockchain-Soroban-purple) ![Python](https://img.shields.io/badge/language-Python-yellow) ![Rust](https://img.shields.io/badge/language-Rust-orange) ![Tests](https://img.shields.io/badge/tests-6%20passed-success) ![License](https://img.shields.io/badge/license-MIT-green)

# Veritas — Privacy-Preserving Credential Verifier on Stellar

> **A ZK credential-compliance layer for Stellar / Soroban.** Prove you're compliant
> ("I'm 18+", "my country is allowed", "this credential is valid & mine") **without**
> revealing the underlying document. A holder generates a Groth16 proof of a *derived
> predicate* and a Soroban contract verifies it **on-chain** via a real BN254 pairing —
> gating a compliant action while DOB, country, and identity stay private.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Stellar](https://img.shields.io/badge/Stellar-Soroban-7d65ff)](https://developers.stellar.org/docs/smart-contracts)
[![ZK](https://img.shields.io/badge/ZK-Groth16%20%2F%20BN254-blue)](https://docs.circom.io)
[![Tests](https://img.shields.io/badge/tests-6%20passing-brightgreen)](soroban/contracts/veritas-verifier)

**Hackathon:** Stellar Hacks: Real-World ZK · **Stack:** Circom + snarkjs + Rust/Soroban + Node

---

## Why this wins (the angle)

Compliance / KYC is the **#1 real-world barrier** to on-chain payments. Today, proving you're
allowed to transact means uploading a passport to a centralized oracle. Veritas replaces that with
**cryptographic proof of a derived predicate**: the verifier learns *only* that the predicate holds,
never the underlying attribute. One design lands three listed use-cases at once — **identity
verification without document exposure**, **private payments**, and **confidential tokens** — and has
the most demo-able ZK story (clear allow / deny outcome).

---

## How it works

```
                         (1) signs credential claim
   ┌─────────┐   ───────────────────────────────────►   ┌─────────┐
   │ ISSUER  │   BabyJub EdDSA-Poseidon signature       │ HOLDER  │
   │ (KYC…)  │   ◄───────────────────────────────────   │ (user)  │
   └─────────┘        public key (Ax, Ay) published      └─────────┘
        │                                                  │  (2) derives predicate
        │                                  ┌───────────────┴───────────────┐
        │                                  ▼                               │
        │                          ┌──────────────┐   private: DOB, country,  │
        │                          │   PROVER     │   signature, salt, secret │
        │   public key on-chain    │ (off-chain)  │ ◄────────────────────────┘
        │     ┌────────────────┐   │ circom+snarkjs│
        │     │ allow-set root │   │ Groth16 proof │
        │     │  (sanctions)   │   └──────┬───────┘
        │     └───────┬────────┘          │ (3) proof + public inputs only
        │             │                   ▼
        ▼             ▼           ┌──────────────────────────────────────┐
   ┌────────────────────────┐     │ SOROBAN VERIFIER CONTRACT            │
   │ set_issuer / set_root  │ ──► │  • BN254 Groth16 pairing (in WASM)   │
   │ (admin config)         │     │  • verify(proof, public) -> bool      │
   └────────────────────────┘     │  • issuer + Merkle-root binding       │
                                  │  • nullifier set (double-spend)       │
                                  │  • claim_faucet() gated action        │
                                  └─────────────────┬────────────────────┘
                                                    │ (4) true → action unlocks
                                                    ▼
                                       compliant transfer / age-gated faucet
```

**Flow:** an issuer signs a credential. The holder runs the prover, which produces a Groth16 proof
of a *derived predicate* (not the attribute itself). They submit `proof + public_inputs` to the
Soroban verifier. The contract runs the BN254 pairing check **on-chain**, enforces that the issuer
pubkey and (optionally) an allow-set Merkle root match on-chain values, records a nullifier to block
replays, and only then unlocks the gated action. The proof reveals **nothing** about the DOB,
country, name, or document.

---

## Circuits (`circuits/`)

| Circuit | Public inputs | Public outputs | Proves (without revealing) |
|---|---|---|---|
| `AgeGte` | `now_year, now_month, now_day, threshold` | `commitment, ageGte` | age ≥ threshold, from a private DOB |
| `ValidOwner` | `issuerAx, issuerAy` | `nullifier, verified` | a credential was issuer-signed & is owned (emits a double-spend nullifier) |
| `JurisdictionAllowed` | `merkleRoot` | `computedRoot, allowed` | country ∈ allow-set (Poseidon Merkle membership) |
| `CredentialAge` *(flagship)* | `issuerAx, issuerAy, threshold` | `nullifier` | issuer-signed credential whose private `age ≥ threshold` (combines the above) |

Primitives: **Poseidon** hash, **EdDSA over BabyJubJub**, **Groth16** on BN254 — all from iden3/circomlib.
An invalid predicate (underage, wrong country, forged signature) makes a circuit **unsatisfiable** —
no proof can ever exist.

---

## The on-chain verifier (`soroban/contracts/veritas-verifier/`)

A Rust Soroban contract that performs the full **Groth16 BN254 pairing check inside WASM** (Stellar
has no BN254 precompile, so the verifier implements the miller-loop / final-exponentiation in the
contract itself via `ark-bn254`). It compiles to **~73 KB of wasm** and exposes:

```rust
verify(proof_bytes, public_inputs_bytes) -> bool         // default circuit
verify_for(circuit_id, proof_bytes, public_inputs_bytes) // explicit predicate
verify_credential(circuit_id, proof_bytes, public_inputs_bytes)
    // verify_for + flag==1 + issuer match + Merkle-root match + nullifier record
claim_faucet(recipient, circuit_id, proof_bytes, public_inputs_bytes) -> bool  // gated action
set_verifying_key / set_default_circuit / set_issuer / set_allowed_root       // admin
```

**Byte encoding** (no length prefixes, big-endian):
- `proof_bytes` (256 B): `A.x A.y | B.x.c0 B.x.c1 B.y.c0 B.y.c1 | C.x C.y`
- `public_inputs_bytes`: `nPublic × 32 B` (snarkjs `public.json` order, outputs then inputs)
- `vk_bytes`: `α(2) β(4) γ(4) δ(4) nPublic(1) IC[(n+1)×2]`

The **same** pairing core (`src/groth16.rs`) is unit-tested against real snarkjs proofs, so the
on-chain math is proven correct beyond doubt (see Tests).

---

## Quick start

### Prerequisites
Node 18+, `circom` 2.x, `snarkjs`, Rust + the `wasm32v1-none` target, and the `stellar` CLI.

```bash
# one-time: add the Soroban wasm target
rustup target add wasm32v1-none
# install JS deps (circomlibjs, snarkjs)
npm install
```

### Run the whole demo (recommended)
```bash
bash scripts/demo.sh
```
This compiles the circuits, runs the trusted setup, generates **real** Groth16 proofs (snarkjs
verifies them off-chain), encodes them into bytes, compiles the Soroban contract, and verifies the
proofs **on-chain in the Soroban sandbox** — including a tampered credential being rejected and a
replayed nullifier being blocked. Expect ~73 KB wasm and all-green output.

### Run just the circuits
```bash
node scripts/gen_test_inputs.js          # issuer signs demo credentials
bash scripts/verify_all.sh               # setup + prove + off-chain verify
node scripts/proof_to_bytes.js AgeGte    # → proof.bin / public.bin / vk.bin
```

### Run the prover / issuer services
```bash
node services/issuer/issue.js 23 18      # issuer signs a "age=23" credential
node services/prover/prove.js ValidOwner # witness + Groth16 proof + on-chain bytes
```

---

## Deploy to Stellar Testnet

```bash
# 1. create + fund a testnet account
stellar keys generate --network testnet
curl "https://friendbot.stellar.org?addr=$(stellar keys address --network testnet)"

# 2. deploy + install the AgeGte vkey + submit a REAL proof
export STELLAR_ADMIN_SECRET="<your testnet secret key>"
bash scripts/deploy_testnet.sh
```
The script deploys the verifier, installs the verifying key, and calls `verify_for` with the real
AgeGte proof bytes — the same bytes the sandbox test verifies — returning `true` on testnet.

> The sandbox demo (`scripts/demo.sh`) exercises the identical WASM the contract deploys, so the
> on-chain verification story is reproducible without spending testnet XLM.

---

## Tests

```bash
cd soroban/contracts/veritas-verifier && cargo test
```
- `tests/verify_real.rs` — verifies REAL snarkjs proofs with the pairing core; rejects a tampered
  threshold and a cross-circuit proof.
- `tests/sandbox.rs` — deploys the contract in the Soroban sandbox and verifies real proofs
  **on-chain**: AgeGte unlocks the faucet, ValidOwner enforces double-spend protection, and
  JurisdictionAllowed binds to the posted Merkle root.

All **6 tests pass**.

---

## Project layout

```
circuits/        Circom sources (AgeGte, ValidOwner, JurisdictionAllowed, CredentialAge)
                 + circomlib deps, ptau, build artifacts, circuit tests
soroban/contracts/veritas-verifier/  Rust Soroban contract: groth16 core + circuit spec + contract + tests
services/issuer/   Off-chain issuer/attester (BabyJub EdDSA-Poseidon signing)
services/prover/   Off-chain prover (witness + Groth16 proof + byte encoding)
scripts/         gen inputs · verify_all · proof_to_bytes · demo.sh · deploy_testnet.sh
python/          Alternative Python toolchain: issuer / witness / proof / verify + demo.sh
Dockerfile       reproducible environment (circom + snarkjs + rust + stellar)
```

---

## Honest limitations & trusted setup

- **Trusted setup:** the demo uses the standard public powers-of-tau (`ptau/`) with a single
  contribution. This is hackathon-grade; production would run a multi-party ceremony. We document
  this rather than hide it.
- **Demo keys** in the issuer are generated fresh each run and are **never** for production.
- **On-chain cost:** a full BN254 pairing in WASM is gas-heavier than a native precompile would be
  (Stellar has none yet). The contract fits comfortably under the wasm size limit; gas on testnet is
  the practical consideration, documented honestly rather than hand-waved.
- **Sanctions non-membership** and a **confidential-token** gated transfer are described as stretch
  goals (see `SUBMISSION.md`), not in the MVP scope.

## Security guardrails
No private keys or API keys are committed. Demo issuer keys are generated in-repo and clearly marked
`DO NOT USE IN PROD`. The repo does **not** submit to any hackathon portal and touches **no** mainnet
funds.

## 📸 Screenshots
| Demo output | Architecture flow |
|---|---|
| ![demo](docs/demo-output.png) | ![arch](docs/architecture.png) |

## License
[MIT](LICENSE). Built for the Stellar Hacks: Real-World ZK hackathon.
