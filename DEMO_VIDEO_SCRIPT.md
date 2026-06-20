# 🎬 Veritas — Demo Video Script (3 min)

> **Title:** Veritas — Privacy-Preserving Credential Verifier on Stellar
> **Hackathon:** Stellar Hacks: Real-World ZK
> **Runtime:** ~3:00 (180s)
> **Format:** Screen-capture + voiceover. One terminal window, plus brief
> code-viewer cuts to the circom sources and the Soroban contract.
>
> **Recording tip:** the whole demo runs in the **Soroban sandbox** — no testnet
> account, no `STELLAR_ADMIN_SECRET`, no real funds needed. Prereq:
> ```bash
> cd veritas-zk && npm install && rustup target add wasm32v1-none
> ```
> (Run `bash scripts/demo.sh` once before recording to pre-build artifacts so the
> on-camera run is snappy.)

---

## SEGMENT 1 — Intro: ZK credentials on Stellar (0:00 – 0:30)

**On screen:** Title card →
*Veritas — Prove you're compliant **without** revealing the document.*
Then the architecture diagram from the README (issuer → holder → prover →
Soroban verifier).

**Voiceover:**
> "Compliance and KYC are the number-one real-world barrier to on-chain payments.
> Today, proving you're allowed to transact means uploading a passport to a
> centralized oracle. **Veritas** fixes that. It's a zero-knowledge credential layer
> for **Stellar Soroban**: a holder generates a Groth16 proof of a *derived
> predicate* — 'I'm 18+', 'my country is allowed', 'this credential is valid and
> mine' — and a Soroban contract verifies it **on-chain** via a real BN254 pairing.
> The verifier learns the predicate holds — and **nothing else** about your date of
> birth, your country, or your identity."

**Cut to:** terminal, prompt ready in `veritas-zk/python/`.

---

## SEGMENT 2 — Run the demo: issuer → witness → proof → verify (0:30 – 1:35)

**On screen:** Run the single end-to-end script:

```bash
bash python/demo.sh
```

**What appears, step by step** (this is the core 65 seconds — let each step land):

### Step 1 — `issuer.py` (issuer signs the credential)
Console prints:
```
=== Veritas ZK Demo ===
Step 1: Generate signed credential
```
A BabyJub EdDSA-Poseidon signature is produced over a credential claim (e.g. an
age). The issuer's public key `(Ax, Ay)` and the signed claim are written out.

**Voiceover:**
> "Step one — the **issuer**, say a KYC provider, signs a credential claim using an
> EdDSA signature over the BabyJubJub curve, with Poseidon hashing. Only the
> issuer's public key ever goes on-chain."

### Step 2 — `witness_gen.py` (holder derives the witness)
Console prints:
```
Step 2: Generate witnesses
```
The prover computes the circuit witness from **private** inputs (DOB, country,
signature, salt, secret) and the public inputs.

**Voiceover:**
> "Step two — the **holder** runs the witness generator. The secret attributes —
> date of birth, country, the signature, a salt — stay private. Only the witness
> is computed, locally and off-chain."

### Step 3 — `proof_gen.py` (Groth16 proof)
Console prints:
```
Step 3: Generate proofs
```
A real Groth16 proof is generated (`proof.bin`, `public.bin`, `vk.bin`).

**Voiceover:**
> "Step three — a real **Groth16 proof** is generated. Note what comes out: a proof,
> and the **public inputs only**. The private attributes never appear."

### Step 4 — `verify.py` (on-chain-style verification)
Console prints:
```
Step 4: Verify proofs
=== Demo complete ===
```
The verifier checks the proof against the public inputs and the verifying key —
returns **valid**.

**Voiceover:**
> "Step four — **verification**. The proof checks out: the predicate holds. The
> verifier learned the claim is true — and nothing about the underlying document."

> 🎬 **Optional beat (trim if tight):** show a **tampered** credential being
> rejected and a **replayed nullifier** being blocked — both print `REJECTED` /
> `double-spend`. This is the strongest visual: allow vs deny. (Covered in
> `bash scripts/demo.sh` at the repo root for the full Soroban-sandbox version.)

---

## SEGMENT 3 — The circom circuit, briefly (1:35 – 2:00)

**On screen:** Cut to a code viewer. Open the flagship circuit:

```bash
# in the repo root
cat circuits/CredentialAge.circom
```

*(Show ~15–20 lines — the signal declarations and the core constraint. Highlight
the private inputs: `dob`, `country`, `signature`, `salt`.)*

**Voiceover:**
> "Under the hood, the predicates are circom circuits. This is the flagship —
> `CredentialAge`: it proves an issuer-signed credential whose private age is at or
> above a threshold. Primitives are Poseidon hashing, EdDSA over BabyJubJub, and
> Groth16 over BN254 — all from circomlib. The key property: an **invalid**
> predicate — underage, wrong country, a forged signature — makes the circuit
> **unsatisfiable**. No proof can ever exist."

---

## SEGMENT 4 — The Soroban verifier contract (2:00 – 2:30)

**On screen:** Cut to the Rust contract:

```bash
cat soroban/contracts/veritas-verifier/src/contract.rs
```

*(Show the `verify_credential` / `claim_faucet` entry points and the on-chain
BN254 pairing call.)*

**Voiceover:**
> "On-chain, this is a Rust Soroban contract. Because Stellar has **no BN254
> precompile**, Veritas implements the full Groth16 pairing — the miller loop and
> final exponentiation — **inside the contract WASM**, using `ark-bn254`. It
> compiles to about 73 kilobytes. The contract enforces issuer binding, an optional
> allow-set Merkle root, records a **nullifier** to block replays, and only then
> unlocks the gated action — like this age-gated faucet."

*(On-screen highlight: `verify_credential(...)` returning `true` →
`claim_faucet(...)` succeeding — both visible in `scripts/demo.sh` sandbox output
if you pre-ran it.)*

---

## SEGMENT 5 — Closing (2:30 – 3:00)

**On screen:** End card →

> **Veritas — Privacy-Preserving Credential Verifier on Stellar**
> Groth16 / BN254 pairing verified **on-chain in Soroban WASM**
> Prove compliance. Keep the document.
> MIT · Stellar Hacks: Real-World ZK

**Voiceover:**
> "Veritas — prove you're compliant **without** revealing the document. A real
> Groth16 proof, a real BN254 pairing verified on-chain inside a Soroban contract.
> One design lands three use-cases at once: identity verification without document
> exposure, private payments, and confidential tokens. The predicate is public.
> The person stays private."

**End card:** repo URL · `bash scripts/demo.sh` · `cd soroban/contracts/veritas-verifier && cargo test`

---

## 🎬 Shot list / recording checklist

| # | Segment | Window | Command / action | Duration |
|---|---------|--------|------------------|----------|
| 1 | Intro | — | Title card + architecture diagram | 30s |
| 2 | Demo flow | Terminal | `bash python/demo.sh` (issuer → witness → proof → verify) | 65s |
| 3 | Circom circuit | Code viewer | `cat circuits/CredentialAge.circom` | 25s |
| 4 | Soroban contract | Code viewer | `cat soroban/contracts/veritas-verifier/src/contract.rs` (+ highlight pairing) | 30s |
| 5 | Closing | — | End card | 30s |

**If you need to save 20s:** trim the tampered-credential/replay beat inside
Segment 2, and show only one `cat` code cut instead of two.

**Captions / lower-thirds to prepare:**
- "Groth16 proof · public inputs only"
- "BN254 pairing verified on-chain in Soroban WASM (~73 KB)"
- "Nullifier set blocks double-spends"
- "Invalid predicate → unsatisfiable circuit → no proof can exist"
- "MIT · Stellar Hacks: Real-World ZK"

**Stronger on-camera version (recommended if time allows):** run
`bash scripts/demo.sh` from the **repo root** instead of `python/demo.sh` — it
additionally compiles the circuits, runs the trusted setup, compiles the Soroban
contract, and verifies real proofs **inside the Soroban sandbox**, including the
tampered-credential rejection and replayed-nullifier block. Same zero-secrets,
no-testnet story; more visually complete.
