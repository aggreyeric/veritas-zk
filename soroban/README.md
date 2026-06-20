# Veritas — Soroban (Stellar) Verifier Contract

On-chain **Groth16** zero-knowledge credential verifier for
[Soroban](https://stellar.org/developers/docs/smart-contracts) (Stellar smart
contracts). The same `no_std` BN254 pairing core runs inside the WASM contract
**and** in host unit tests that verify **real** snarkjs proofs — so the on-chain
pairing math is provably correct.

The contract stores one verifying key per Veritas circom circuit, a trusted
issuer pubkey, an allow-set Merkle root, and a nullifier set (double-spend
protection), then exposes pure `verify` / `verify_for` / `verify_credential`
entry points and a proof-gated `claim_faucet` action.

> This directory is the Soroban half of the `veritas-zk` monorepo. The circom
> circuits, trusted-setup (ptau), zkeys and proofs live in `../circuits/`.

---

## Layout

```
soroban/
└── contracts/
    └── veritas-verifier/
        ├── Cargo.toml              # crate config (cdylib + rlib)
        ├── src/
        │   ├── lib.rs              # crate root; wires modules together
        │   ├── groth16.rs          # no_std + alloc BN254 / Groth16 verify core
        │   ├── spec.rs             # per-circuit public-signal layout
        │   └── contract.rs         # VeritasVerifier Soroban contract
        ├── tests/
        │   ├── verify_real.rs      # verifies REAL snarkjs proofs (host pairing)
        │   └── sandbox.rs          # deploys contract in sandbox, verifies on-chain
        └── test_snapshots/         # golden snapshots for sandbox tests
```

---

## Prerequisites

| Tool | Version used | Notes |
|------|--------------|-------|
| Rust toolchain | cargo **1.94.0** | `rustup default stable` |
| `wasm32v1-none` target | ✓ installed | `rustup target add wasm32v1-none` |
| `wasm32-unknown-unknown` target | ✓ installed | `rustup target add wasm32-unknown-unknown` |
| Stellar CLI | **27.0.0** | `brew install stellar-cli` (the `soroban` CLI is now the `stellar contract ...` subcommand) |
| circom zkeys + proofs | present | built under `../circuits/build/zkeys/` |

Check your environment:

```bash
cargo --version                         # cargo 1.94.0
rustup target list --installed | grep wasm
stellar --version                       # stellar 27.0.0
```

---

## Build

From `soroban/contracts/veritas-verifier/`:

```bash
# Host build (fast compile-time checks). Always passes.
cargo build

# Release WASM contract for Soroban (this is what gets deployed).
cargo build --release --target wasm32v1-none
```

The release build emits the deployable contract at:

```
soroban/contracts/veritas-verifier/target/wasm32v1-none/release/veritas_verifier.wasm
```

Optimisation profile (`Cargo.toml`): `opt-level = "z"`, `overflow-checks = true`,
`panic = "abort"`, `strip = "symbols"` — minimal on-chain footprint.

---

## Test

```bash
cd soroban/contracts/veritas-verifier

# All tests: 2 host correctness suites against REAL snarkjs proofs.
cargo test
cargo test --test verify_real -- --nocapture   # host pairing vs snarkjs
cargo test --test sandbox      -- --nocapture   # deployed-contract e2e
```

Expected (all green):

```
sandbox      :: age_gte_verifies_on_chain ........... ok
               jurisdiction_allowed_verifies_on_chain ok
               valid_owner_double_spend_protection ... ok
verify_real  :: verifies_all_real_proofs ............ ok
               rejects_tampered_public_input ........ ok
               rejects_cross_circuit_proof .......... ok

test result: ok. 3 passed; 0 failed   (x2)
```

These tests read real proofs/keys from `../circuits/build/zkeys/`
(`AgeGte_*`, `JurisdictionAllowed_*`, `ValidOwner_*`). If you regenerate the
circuits (`cd ../circuits && npm run build`), the tests pick up the new proofs
automatically.

---

## Deploy

> Tested with Stellar CLI **27.x** (`stellar contract ...`). On older Soroban
> CLIs, swap `stellar contract` → `soroban contract`.

### 1. Build the WASM

```bash
cd soroban/contracts/veritas-verifier
cargo build --release --target wasm32v1-none
```

### 2. (Local) Stand up a sandbox network + admin identity

```bash
NETWORK="--rpc-url https://localhost:8000 --network-passphrase 'Standalone Network ; February 2017'"
ADMIN="$(stellar keys generate alice --network '$NETWORK_PASSPHRASE' 2>/dev/null; echo $ALICE)"
# or use the docker sandbox:
docker run --rm -d -p 8000:8000 \
  stellar/quickstart:soroban-dev --enable-soroban-rpc --enable-soroban-diagnostic-events
```

### 3. Install the contract

```bash
WASM=soroban/contracts/veritas-verifier/target/wasm32v1-none/release/veritas_verifier.wasm

stellar contract deploy \
  --wasm "$WASM" \
  --source alice \
  --network testnet
# => CONTRACT_ID=G...

# One-time constructor: register the admin (deployer).
stellar contract invoke \
  --id "$CONTRACT_ID" --source alice --network testnet \
  -- __constructor --admin "$ADMIN_ADDR"
```

### 4. Configure (admin only)

Circuit IDs (see `src/spec.rs`): `0 = AgeGte`, `1 = ValidOwner`,
`2 = JurisdictionAllowed`, `3 = CredentialAge`.

```bash
# Install the Groth16 verifying key for a circuit (raw big-endian bytes).
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- set_verifying_key \
     --circuit 0 \
     --vk "$(xxd -p -c0 ../circuits/build/zkeys/AgeGte_vk.bin)"

# Which circuit verify() (no circuit arg) targets.
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- set_default_circuit --circuit 0

# Trusted issuer BabyJub pubkey (ax, ay) + allow-set Merkle root.
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- set_issuer --ax <ax_32B_hex> --ay <ay_32B_hex>
stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- set_allowed_root --root <merkle_root_32B_hex>
```

---

## Contract API

### Admin configurators (require `admin`)

| Method | Args | Effect |
|--------|------|--------|
| `__constructor` | `admin: Address` | one-time setup; stores deployer as admin |
| `set_verifying_key` | `circuit: u32`, `vk: Bytes` | install/replace Groth16 VK for a circuit |
| `set_default_circuit` | `circuit: u32` | circuit targeted by `verify()` |
| `set_issuer` | `ax, ay: BytesN<32>` | trusted issuer BabyJub pubkey |
| `set_allowed_root` | `root: BytesN<32>` | allow-set Merkle root (JurisdictionAllowed) |

### Verification / actions (open)

| Method | Args | Returns | Notes |
|--------|------|---------|-------|
| `verify` | `proof: Bytes`, `public: Bytes` | `bool` | pure Groth16 check vs default circuit |
| `verify_for` | `circuit: u32`, `proof: Bytes`, `public: Bytes` | `bool` | explicit circuit |
| `verify_credential` | `circuit, proof, public` | `bool` | `verify_for` + issuer/nullifier/flag semantics |
| `claim_faucet` | `circuit, proof, public` | — | gated action; unlocks only on valid proof |
| `admin` | — | `Address` | read admin |
| `last_claimant` | — | `Option<Address>` | read last faucet claimer |

### Byte encodings (big-endian, no length prefixes)

See the module docs in `src/contract.rs`:

- **`proof` (256 B):** `A.x|A.y | B.x.c0|B.x.c1|B.y.c0|B.y.c1 | C.x|C.y`
  (8 × 32-byte field elements; G2 stores `c0` **before** `c1`, matching arkworks).
- **`public`:** `nPublic × 32 B` Fr scalars in snarkjs `public.json` order
  (outputs then inputs, **no** leading `1`).
- **`vk`:** `α.x|α.y | β.{c0,c1}×2 | γ... | δ... | nPublic(1 B) |
  (nPublic+1) × (IC.x|IC.y)`.

---

## Verify a real proof on-chain

```bash
# proof.bin / public.bin are produced by snarkjs groth16 prove for each circuit.
PROOF_B64="$(base64 < ../circuits/build/zkeys/AgeGte_proof.bin)"
PUB_B64="$(base64 < ../circuits/build/zkeys/AgeGte_public.bin)"

stellar contract invoke --id "$CONTRACT_ID" --source alice --network testnet \
  -- verify_for \
     --circuit 0 \
     --proof "$PROOF_B64" \
     --public "$PUB_B64"
# => true
```

---

## Notes

- The `alloc` feature on `soroban-sdk` is **required** — it supplies the WASM
  bump-pointer global allocator + panic handler that arkworks / `Vec` need.
- 9-char short symbols (`admin`, `default`, …) avoid the 32-byte long-symbol
  cost on Soroban.
- `tests/sandbox.rs` is the "meaningful ZK integration with Stellar" proof:
  the on-chain contract accepts real Groth16 proofs and returns the correct
  verdict; `tests/verify_real.rs` additionally asserts rejection of tampered
  inputs and cross-circuit proofs.
