# ERIC — DoraHacks Submission Checklist (Stellar Hacks ZK)

> Do this yourself, in order. Submit only — nothing destructive here.

1. **Open** https://dorahacks.io/hackathon/stellar-hacks-zk
   — If 404, search DoraHacks for "stellar zk" and use the real URL.

2. **Connect wallet** (Freighter/Albedo) if the page prompts — only needed to submit.

3. **Click "Submit Project"** — usually top-right or in the hackathon banner.

4. **Project Name:** `Veritas ZK — Zero-Knowledge Credential Verifier`

5. **Description** — paste this whole block:

```text
Veritas ZK is a privacy-preserving credential-compliance layer for Stellar / Soroban. A holder generates a Groth16 zero-knowledge proof that a derived predicate about their credential holds — "I'm 18+", "this credential is mine and valid", "my country is in the allow-set" — and a Soroban smart contract verifies that proof on-chain via a real BN254 pairing. The verifier learns only that the predicate holds; the date of birth, country, name, and underlying document never leave the holder's device.

Why this matters: KYC, AML, and sanctions compliance is the single biggest barrier to real-world on-chain payments. Today, proving you may transact means uploading a passport to a centralized oracle — a privacy and custody nightmare. ZK credentials replace document disclosure with cryptographic proof: the contract learns "this person is 18+", never their date of birth. An invalid predicate makes the circuit unsatisfiable — no proof can ever exist — so forgery is impossible, not merely discouraged.

How it works: an issuer signs a credential claim with EdDSA-Poseidon over BabyJubJub. The holder derives a predicate and produces a Groth16 proof in circom on top of circomlib (Poseidon hash, BabyJubJub, Groth16 over BN254). Because Stellar has no BN254 precompile, Veritas implements the full Groth16 verification — miller-loop and final-exponentiation — inside a no_std Soroban contract using ark-bn254, exposing verify_for(circuit_id, proof, public) and verify_credential (proof + issuer-pubkey match + Merkle-root match + nullifier record for double-spend protection). One signed credential yields reusable proofs across dApps.
```

6. **GitHub Repository:** https://github.com/aggreyeric/veritas-zk

7. **Demo Video:** record from `DEMO_VIDEO_SCRIPT.md`, or skip if DoraHacks doesn't require it.

8. **Screenshot:** upload `docs/demo-screenshot.png`.

9. **Submit.** 🎉 Copy the project URL and send it back.

10. ⚠️ **If submit fails on repo size (>100MB):** DoraHacks may reject the ~101MB repo (circom build artifacts in git history). Run `git filter-repo` to strip `.r1cs/.wasm/powers-of-tau/witness`, force-push, retry. Note it and ping me — don't redo from scratch.
