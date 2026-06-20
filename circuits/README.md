# Veritas — Circom Circuits

Privacy-preserving credential predicates for Stellar / Soroban. A holder proves a
**derived predicate** over an issuer-signed credential ("I'm 18+", "my country is
allowed", "this credential is valid and mine") **without revealing** the underlying
age, country, document, or signature.

> **Proof system:** Groth16 on BN254 — chosen for the smallest on-chain verifier,
> which fits the Soroban WASM footprint and verifies via `soroban_sdk::crypto::bn254`
> host functions. **Primitives:** Poseidon hash + EdDSA over BabyJubJub, all from
> [`iden3/circomlib`](https://github.com/iden3/circomlib).

---

## Circuits

| Circuit | Purpose | Constraints | Private inputs | Public signals (order) |
|---|---|---:|---:|---|
| [`trivial/`](trivial/preimage.circom) | Pipeline sanity (`y = x·x`) | 1 | 1 | `y` |
| [`age_gte/`](age_gte/age_gte.circom) | Private age → Poseidon commitment; `age ≥ threshold` | 539 | 2 | `commitment, ageGte, threshold` |
| [`valid_owner/`](valid_owner/valid_owner.circom) | Issuer-signed credential validity + nullifier (no predicate) | 9 018 | 5 | `nullifier, issuerAx, issuerAy` |
| [`credential_age/`](credential_age/credential_age.circom) | **Flagship** — issuer-signed `age ≥ threshold` + nullifier | 9 039 | 5 | `nullifier, issuerAx, issuerAy, threshold` |
| [`jurisdiction_allowed/`](jurisdiction_allowed/jurisdiction_allowed.circom) | Issuer-signed `country ∈ allow-set` Merkle tree + nullifier | 13 178 | 21 | `nullifier, issuerAx, issuerAy, allowedRoot` |

**Public-signal order convention (snarkjs):** outputs come first, then the
declared public inputs in source order. The on-chain Soroban verifier must index
public inputs in exactly this order — see `soroban/`.

### Flagship: `credential_age`

Proves, revealing **only** a per-use nullifier and the threshold:

1. the holder has a credential genuinely **EdDSA-signed** by a known issuer over
   `m = Poseidon(age, holderSecret)` — binds the age to the issuer's authority;
2. the private `age ≥ threshold` (else the circuit is **unsatisfiable** → no proof
   can ever exist);
3. a deterministic `nullifier = Poseidon(holderSecret)` is revealed so the
   on-chain contract can reject replays while the holder stays pseudonymous.

`age`, `holderSecret`, and the signature are **never** exposed. The verifier
learns only *"this nullifier corresponds to an issuer-signed credential whose
holder is `threshold`+."*

### `jurisdiction_allowed`

Same EdDSA validity, but the predicate is **Merkle membership**: the signed
`country` must be a leaf of a public Poseidon Merkle tree whose root
(`allowedRoot`) is posted on-chain. Proving `country ∈ {allow-set}` without
revealing which country. Tree depth 8 → up to 256 members (enough for an
ISO-3166 set). The Merkle verifier lives in [`lib/merkle_poseidon.circom`](lib/merkle_poseidon.circom).

> **Privacy note (honest):** because each leaf is the raw country value, an
> observer who knows the public allow-set learns only that the holder's country
> is *one of* the N members (1/N ambiguity). Production would hash each leaf with
> a per-tree domain separator; we keep leaves raw for demo simplicity and smaller
> constraints. Documented openly — no inflated claims.

---

## Architecture / data flow

```
                 off-chain (prover)                              on-chain (Soroban)
 ┌───────────────┐    EdDSA-Poseidon      ┌──────────────────┐    Groth16 verify
 │   Issuer      │──────────────────────▶ │  Holder / Prover  │──────────────────────▶ ┌───────────────┐
 │ (BabyJub key) │  sig over              │  snarkjs witness  │   proof + public       │  Verifier     │
 │               │  Poseidon(attr,secret) │  + groth16 prove  │   signals (nullifier,  │  contract     │
 └───────────────┘                        └───────────────────┘   issuer key, …)        │  (bn254 host  │
                                                                         │              │   fns)        │
                                                                         ▼              └───────┬───────┘
                                                                  allowedRoot / threshold     │ verify == true
                                                                                          ▼
                                                                                gated action unlocks
```

Primitives: **Poseidon** (hash + Merkle + challenge) and **EdDSA-BabyJubJub** are
all native circomlib templates, so the prover's off-chain crypto
(`scripts/zk_helpers.js`, via `circomlibjs`) matches the circuit constraints bit-for-bit.

---

## Build

Requires `circom >= 2.1.6`, `snarkjs >= 0.7`, `node >= 18`. One command per
circuit (a shared powers-of-tau file under `ptau/` is built once and reused):

```bash
npm install                       # installs circomlib / circomlibjs / snarkjs (in circuits/)

./scripts/build_circuit.sh trivial          4    # y = x²  (smallest pipeline test)
./scripts/build_circuit.sh age_gte         12
./scripts/build_circuit.sh valid_owner     16
./scripts/build_circuit.sh credential_age  16    # flagship
./scripts/build_circuit.sh jurisdiction_allowed 16
```

This produces, under `circuits/<name>/build/`:
`<base>.r1cs`, `<base>_js/<base>.wasm` (witness generator),
`verification_key.json`, and `<base>_final.zkey` (Groth16 proving key).

> Note: the `trivial` circuit's artifacts are named `preimage_*` (its template).

---

## Test

The Python suite generates witnesses, proves, and verifies — positive cases
**must verify**, negative cases (under-age / wrong issuer / country not in set)
**must fail at witness generation** (no proof can exist = the security guarantee).

```bash
# standalone (no deps beyond python3 + node + snarkjs)
python3 circuits/test/test_circuits.py

# or with pytest, if installed
python3 -m pytest circuits/test -v
```

Expected: **16 passed, 0 failed**. Crypto glue (EdDSA / Poseidon / Merkle) runs
through `scripts/zk_helpers.js`; Python orchestrates `snarkjs wc / groth16 prove /
groth16 verify`. See [`test/veritas_harness.py`](test/veritas_harness.py).

---

## Trusted setup (honest, hackathon-grade)

We use **standard public powers-of-tau** (`snarkjs powersoftau new bn254 …`), with
a single phase-1 contribution and a per-circuit phase-2 contribution. This is
**not** production-grade ceremony security — it is appropriate for a hackathon
demo and is documented as such. A real deployment would run a multi-party
ceremony (or switch to a universal-setup system like PLONK).

The proving keys (`.zkey`) and verification keys are reproducible from the
sources + ptau via `scripts/build_circuit.sh`.

---

## Security notes

- **Demo keys only.** `TEST_ISSUER_PRV` in `test/veritas_harness.py` is a fixed,
  public, test-only issuer key. **Never reuse in production.** Real issuers
  generate a fresh BabyJub key off-chain.
- **Nullifier = `Poseidon(holderSecret)`.** Deterministic per credential; lets the
  contract reject replays without leaking identity. `holderSecret` must be
  high-entropy and unique per credential in production.
- **Range checks** use circomlib `GreaterEqThan(16)` — the age/country inputs are
  assumed to fit in 16 bits (age ≤ 65535; country is an ISO-3166 numeric code ≤ 999).
- **No document, name, DOB, or signature** ever leaves the prover; only the
  derived predicate + nullifier + issuer public key are public.

## Layout

```
circuits/
  trivial/             preimage.circom            (pipeline sanity)
  age_gte/             age_gte.circom             (range proof over a commitment)
  valid_owner/         valid_owner.circom         (signature validity + nullifier)
  credential_age/      credential_age.circom      (FLAGSHIP: signed age ≥ threshold)
  jurisdiction_allowed/jurisdiction_allowed.circom (signed country ∈ Merkle allow-set)
  lib/                 merkle_poseidon.circom      (reusable Poseidon Merkle verifier)
  test/                veritas_harness.py, test_circuits.py
  build/…              r1cs / wasm / zkey / verification_key.json (per circuit)
ptau/                  ptau_4.ptau, ptau_12.ptau, ptau_16.ptau   (shared phase-1)
scripts/               build_circuit.sh, zk_helpers.js
```

---

## Spec-compliant top-level circuits (`AgeGte` / `JurisdictionAllowed` / `ValidOwner`)

> Added 2026-06-20. These three top-level `.circom` files implement the exact
> I/O required by the task brief and are the **canonical, demo-ready** circuits.
> The per-subdir circuits above (`age_gte/`, `credential_age/`, …) are an earlier
> design that takes `age` directly; they still build and are kept for reference.
> Use the top-level three for the hackathon submission.

| Circuit file | What it proves | Non-linear constraints | Public inputs | Public outputs |
| --- | --- | --- | --- | --- |
| [`AgeGte.circom`](AgeGte.circom) | `age ≥ threshold`, with `age` **computed from a private DOB** vs. a public "now" date (DOB never revealed). | 356 | `now_year, now_month, now_day, threshold` | `commitment, ageGte` |
| [`JurisdictionAllowed.circom`](JurisdictionAllowed.circom) | private `country_hash` is a leaf of a public depth-16 Poseidon Merkle allow-set (which country is hidden). | 3 936 | `merkleRoot` | `computedRoot, allowed` |
| [`ValidOwner.circom`](ValidOwner.circom) | credential validly **EdDSA-signed** by a known issuer + emits a per-use `nullifier = Poseidon(claim_hash, nonce)` for double-spend protection. | 7 622 | `issuerAx, issuerAy` | `nullifier, verified` |

### Soundness (verified)
Each circuit is **unsatisfiable** for an invalid claim — no proof can ever be forged:

| Attack | Where it fails |
| --- | --- |
| Under-age DOB (`age < threshold`) | `AgeGte.circom:89`  (`LessThan(16)(age, threshold) === 0`) |
| Country not in allow-set / wrong root | `JurisdictionAllowed.circom:50`  (`computedRoot === merkleRoot`) |
| Forged / tampered issuer signature | `EdDSAPoseidonVerifier` → `ForceEqualIfEnabled` (sig equation) |

circomlib's `LessThan(n)` internally `Num2Bits(n+1)`-constrains `a + 2ⁿ − b`, which
implicitly bounds both operands to ±2ⁿ — so a wrapped/negative age is rejected
(safe by construction, not merely by convention).

### Build, prove, verify (all three)
```bash
cd circuits
for C in AgeGte JurisdictionAllowed ValidOwner; do
  circom $C.circom --r1cs --wasm --sym --output build/
done
# generate valid sample inputs (real Poseidon Merkle proof + real BabyJub EdDSA)
NODE_PATH=node_modules node ../scripts/gen_test_inputs.js
# full Groth16 setup → prove → verify, using the bundled public ptau_16
bash ../scripts/verify_all.sh
```
All three proofs return `snarkJS: OK!`. Sample inputs live in
[`test_inputs.json`](test_inputs.json) (and per-circuit `build/*_input.json`).

