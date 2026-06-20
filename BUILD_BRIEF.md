# BUILD BRIEF: Veritas — Privacy-Preserving Credential Verifier on Stellar
# Hackathon: Stellar Hacks: Real-World ZK
# URL: https://dorahacks.io/hackathon/stellar-hacks-zk
# Dates: June 15–29, 2026 (two-week competition)
# Prize: $10,000 in XLM across top 5 projects — 1st $5,000 / 5th $750 (mid tiers TBC)
# Runtime: QwenPaw Worker (HiClaw). Owner: Eric. Orchestrator: HICLAW_MANAGER.

## PRIZE (confirmed 2026-06-18 via SDF announcement / LumenLoop)
- Total pool: **$10,000 in XLM**, paid across the **top 5 projects**.
- Confirmed tiers: **1st = $5,000**, **5th = $750**.
- Middle tiers (2nd–4th) not explicitly published; they sum to ~$4,250 (likely 2nd≈$2k / 3rd≈$1.5k / 4th≈$750) — verify on the DoraHacks page before submitting. Do NOT quote mid tiers as fact.
- Submission requirements: **open-source repo** + **2–3 min demo video** (talking head optional) + **meaningful ZK integration with Stellar mainnet OR testnet**.

## WHAT TO BUILD (the angle = why this wins)
A **ZK credential-compliance layer for Soroban**. A user holds a signed credential
(age / jurisdiction / accreditation / non-sanctioned). They generate a zero-knowledge
proof of a *derived predicate* ("I am 18+", "my country is allowed", "I'm not on the
sanctions list", "this credential is valid & mine") WITHOUT revealing the underlying
document, DOB, name, or country. A Soroban verifier contract checks the proof on-chain
to gate a compliant action.

This is the strongest angle because it lands THREE of the listed use-cases at once —
**identity verification without document exposure + private payments + confidential
tokens** — and "compliance" is the #1 real-world barrier to on-chain payments (judges'
real-world relevance box, checked). It also has the most demo-able ZK story.

## SCOPE (2-week solo Worker — keep it tight)
### MVP (must finish, demo-defining)
1. **Issuer/attester** (off-chain, Node/TS): signs a credential claim with **EdDSA on BabyJub**
   (circomlib-native, efficient inside the SNARK). Claim = JSON of attributes → Poseidon hash.
2. **Circom circuit(s)** proving derived predicates:
   - `AgeGte(claim, issuerSig, salt, now)` → age ≥ 18 (range proof on DOB field).
   - `JurisdictionAllowed(claim, issuerSig, salt, allowedRoot)` → country ∈ allowed-set Merkle.
   - `ValidOwner(claim, issuerSig, salt, nullifier)` → credential valid & tied to holder, emits a
     per-use nullifier (double-spend protection) without leaking identity.
   - Hash = **Poseidon**; signature = **EdDSA BabyJub**; proof system = **Groth16** (smallest
     verifier, fits Soroban WASM).
3. **Soroban verifier contract (Rust)**: stores issuer pubkey + (optionally) a revocation/sanctions
   Merkle root. Exposes `verify(proof, public_inputs) -> bool`. This is the "meaningful ZK integration
   with Stellar" — the on-chain verifier is the heart of the submission.
4. **Gated demo action (Soroban)**: an "age-gated faucet" or "compliant transfer" contract that only
   executes when `verify` returns true.
5. **Prover service (Node/TS, off-chain)**: snarkjs witness + proof generation from the user's credential.

### STRETCH (only after MVP is solid)
- Sanctions non-membership: prover proves "not in OFAC-style Merkle root" posted on-chain.
- Compliance-gated **confidential token transfer** (ties in "private payments / confidential tokens").
- Trusted-setup note in README (we use public Ptau for a hackathon; document it honestly).

## TECH PATH & THE ONE BIG RISK
- **Stellar smart contracts = Soroban (Rust → WASM).**
- **ZK verify on Stellar:** compile Circom → Groth16, generate the verifier, port it to a Soroban
  contract. Ecosystem precedent exists ("Verifying Circom Zero-Knowledge Circuits On Stellar"). Tools:
  circom, snarkjs, @stellar/soroban-sdk (Rust), `cargo test`.
- **🔴 CORE RISK:** BN254 pairing precompiles may not exist on Soroban → the Groth16 verifier must do
  pairing math in WASM. Mitigations, in order: (a) find a working open-source Soroban Groth16/PLONK
  verifier and adapt it; (b) if pairing is too heavy, fall back to **PLONK/Fflonk** or to verifying a
  STARK/proof with a smaller footprint; (c) as a last resort for the DEMO, verify a small Groth16
  proof and document gas/size limits. Resolve this risk in **day 1–2** (spike: one trivial circuit →
  verify on Soroban testnet) before building the rest.
- Chain: **Stellar Testnet** first (fast iteration); note mainnet path in README.

## DELIVERABLES (matches the bar exactly)
- Public repo: circuits/, soroban/ (Rust), prover/ (TS), scripts/, README.md, LICENSE (MIT/Apache).
- README: what it does, architecture diagram, how ZK↔Stellar works, how to run end-to-end, the
  pre-existing-vs-new contributions split (REQUIRED — they check this), known limitations.
- 2–3 min demo video: issue credential → generate proof off-chain → verify ON-CHAIN on Soroban →
  gated action unlocks. Show the proof being rejected for a wrong/invalid credential too.
- Reproducible: pinned deps, setup steps, a script that runs the whole flow on testnet.

## JUDGING-CRITERIA ALIGNMENT
- Real-world relevance: ✅ compliance/KYC is the top barrier to payments.
- Meaningful ZK integration: ✅ proof is verified ON-CHAIN by a Soroban contract.
- Originality: ✅ compliance-credential-as-private-predicate on Stellar is fresh.
- Demoability: ✅ clear allow/deny visual outcome.

## RESOURCES
- Hackathon: https://dorahacks.io/hackathon/stellar-hacks-zk (Telegram group via that page for mentor Q&A).
- Soroban docs: https://developers.stellar.org/docs/smart-contracts
- Circom + circomlib: https://docs.circom.io / https://github.com/iden3/circomlib
- snarkjs: https://github.com/iden3/snarkjs
- "Verifying Circom circuits on Stellar" (ecosystem precedent — find & study this early).
- Poseidon / BabyJub EdDSA: all in circomlib.

## TECH STACK
Rust (Soroban) + TypeScript (prover/issuer) + Circom + snarkjs. Minimal, reproducible deps.

## SECURITY & GUARDRAILS
- No private keys or API keys in the repo. Any issuer/attester keys in the demo are test-only, generated in-repo, clearly marked DO NOT USE IN PROD.
- Trusted-setup: use the standard public powers-of-tau files; document that this is hackathon-grade.

## DO NOT
- Do NOT submit to DoraHacks (Eric approves ALL submissions).
- Do NOT touch mainnet funds or launch any token.
- Do NOT quote the mid-tier prize numbers as confirmed — they're an estimate.
- Do NOT inflate the ZK claim: if on-chain verification turns out infeasible, pivot the proof type rather than faking "verified on Stellar."
