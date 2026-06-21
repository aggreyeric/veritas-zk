# Veritas — DoraHacks Submission Form Fields

**Hackathon:** Stellar Hacks ZK · DoraHacks
**URL:** https://dorahacks.io/hackathon/stellar-hacks-zk
**Prize:** $10K XLM · **Deadline:** Jun 29
**Status:** Copy-paste-ready fields. NOT submitted anywhere. (Eric approves before submit.)

---

> Each field below is formatted as: the DoraHacks form label → the exact text to paste.
> All fields are self-contained and within stated limits.

---

## 1. Project Name

```
Veritas — Privacy-Preserving Credential Verifier on Stellar
```

(Short form if the field is tiny: `Veritas`)

---

## 2. One-line Tagline (max 255 chars)

```
Prove you're compliant — without revealing the document. Veritas is a ZK credential-compliance layer for Soroban: holders generate Groth16 proofs of derived predicates and a Soroban contract verifies them on-chain via a real BN254 pairing.
```

_Character count: ~243 — within the 255 limit._

**Shorter fallback (~170 chars) if the field is tighter:**
```
A ZK credential-compliance layer for Stellar: prove "I'm 18+", "jurisdiction-allowed", or "valid owner" with a Groth16 proof verified on-chain by a real BN254 pairing.
```

---

## 3. Description (500–800 words)

```
Veritas is a privacy-preserving credential-compliance layer for Stellar / Soroban. It lets a user prove a derived predicate about themselves — "I'm 18+", "my country is allowed", "this credential is valid and mine" — with a Groth16 zero-knowledge proof, while a Soroban smart contract verifies that proof on-chain via a real BN254 pairing. The verifier learns only that the predicate holds. The date of birth, country, name, and underlying document never leave the holder's device.

**The problem.** Compliance / KYC is the single biggest barrier to real-world on-chain payments. Today, proving you may transact means uploading a passport to a centralized oracle — a privacy and custody nightmare that banks cite as a core reason they won't settle on public chains. Veritas replaces document disclosure with cryptographic proof of a derived predicate: the contract learns "this person is 18+", never their date of birth.

**What "ZK identity" means here.** Zero-knowledge identity isn't about hiding who you are — it's about revealing the minimum a verifier needs. An issuer signs a credential claim with EdDSA-Poseidon over BabyJubJub. The holder then generates a Groth16 proof that a predicate derived from that credential holds. An invalid predicate — underage, wrong country, forged signature — makes the circuit unsatisfiable: no proof can ever exist. Proofs are reusable across dApps, with on-chain double-spend protection via per-use nullifiers.

**Three predicate circuits, one architecture.** Built in circom on top of circomlib (Poseidon hash, BabyJubJub EdDSA, Groth16 over BN254):

- **AgeGte** — proves age ≥ threshold from a private date-of-birth, without revealing the DOB.
- **ValidOwner** — proves a credential was issuer-signed and is owned by the prover, emitting a double-spend nullifier.
- **JurisdictionAllowed** — proves the holder's country is a member of an allow-set, via a Poseidon Merkle-membership proof against an on-chain root (e.g. a sanctions allow-list).

A flagship fourth circuit, **CredentialAge**, composes these primitives: an issuer-signed credential whose private age exceeds a threshold, emitting a nullifier. One signed credential yields age, jurisdiction, and ownership proofs reusable across dApps.

**The on-chain verifier — the core of the submission.** Stellar has no BN254 precompile, so Veritas implements the full Groth16 verification — miller-loop and final-exponentiation — inside a `#![no_std]` Soroban contract using `ark-bn254`. It compiles to ~73 KB of WASM and exposes `verify_for(circuit_id, proof, public)`, plus `verify_credential` (proof + issuer-pubkey match + Merkle-root match + nullifier record) and `claim_faucet` (the gated action). The same pairing core is unit-tested against real snarkjs proofs, and a Soroban sandbox test deploys the contract and verifies the identical proofs on-chain. All 6 tests pass. The deploy script submits that same proof to Stellar testnet — `verify_for(...) → true`.

**A full Python toolchain.** Alongside the Node / circom / snarkjs pipeline, Veritas ships a pure-Python implementation of the entire off-chain flow: issuer signing, witness generation, proof generation, and verification (`python/issuer.py`, `witness_gen.py`, `proof_gen.py`, `verify.py`, runnable end-to-end via `python/demo.sh`). This makes the issuer/prover logic auditable and hackable in the language most ZK researchers reach for first, and serves as an independent cross-check of the Node toolchain.

**Why it matters.** KYC / AML / sanctions compliance is the gate every regulated payment passes through. Veritas turns that gate into a privacy-preserving on-chain primitive: a stablecoin issuer can gate transfers by jurisdiction, an exchange can prove accreditation without PII, a DeFi protocol can enforce sanctions screening via an on-chain allow-set root. One design lands three real-world use-cases at once — identity verification without document exposure, private payments, and confidential tokens.

**Reproducibility.** One script, `scripts/demo.sh`, takes you from signed credential → Groth16 proof → on-chain verification → gated faucet unlock → tampered-proof rejection. Every byte the contract sees is generated by the open pipeline. No stubs, no fake "verified" flags.

**Honesty.** The demo uses the standard public powers-of-tau with a single contribution (hackathon-grade; production needs a multi-party ceremony). On-chain pairing gas is heavier than a hypothetical native precompile — documented plainly rather than hidden. Demo keys are generated fresh and marked DO NOT USE IN PROD. The repo touches no mainnet funds.
```

_Word count: ~720 — within the 500–800 range._

---

## 4. Demo Video URL

```
[Eric: add link]
```

> Drop the YouTube / Loom / Bilibili link here before submitting. Suggested 2–3 min: run `bash scripts/demo.sh` on screen, then show `deploy_testnet.sh` returning `true`. The tampered-proof rejection (~line 4 of the demo) is the money shot for judges.

---

## 5. GitHub Repo URL

```
https://github.com/aggreyeric/veritas-zk
```

> Confirm the repo is **public** and the README renders (badges + flow diagram) before submitting.

---

## 6. Category / Track Suggestion

**Primary:**
```
Real-World ZK — Identity & Privacy
```

**Alternatives (pick whichever DoraHacks track name matches):**
```
- ZK for Identity & Compliance
- Privacy & Zero-Knowledge
- DeFi / Payments Infrastructure
```

**Rationale (one line, in case the form asks):** Veritas turns KYC/AML/sanctions compliance — the #1 barrier to real-world on-chain payments — into a privacy-preserving on-chain primitive via ZK proofs verified on Soroban. It hits identity verification, private payments, and confidential tokens in one design.

---

## Pre-submit checklist (for Eric)

- [ ] Repo `aggreyeric/veritas-zk` is public, README renders with badges + diagram
- [ ] Demo video recorded + link pasted into field 4
- [ ] All 6 tests pass locally (`cd soroban/contracts/veritas-verifier && cargo test`)
- [ ] `scripts/demo.sh` runs clean end-to-end
- [ ] Tagline fits the 255-char field (paste field 2 verbatim)
- [ ] Description fits the form's word/char limit (trim the Honesty paragraph first if needed)
- [ ] Final go/no-go from Eric before clicking submit

---

_Prepared by hack_3. Not submitted anywhere — awaiting Eric's approval._
