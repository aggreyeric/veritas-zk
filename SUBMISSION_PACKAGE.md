# Veritas ZK — Submission Package

> **The one doc Eric needs to submit. Everything copy-paste-ready. ~10 minutes end to end.**
> Status: **NOT submitted anywhere.** Awaits Eric's explicit go/no-go.

---

## 🎯 TL;DR

| Field | Value |
|---|---|
| **Project name** | **Veritas ZK — Zero-Knowledge Credential Verifier** |
| **Tagline (one punchy line)** | **Prove credentials without revealing them — circom + Groth16 proofs, verified on-chain by a real BN254 pairing inside a Soroban contract.** |
| **Hackathon** | **Stellar Hacks ZK** (Real-World ZK) · **DoraHacks** |
| **Track** | **Stellar ZK — Track #15** (Real-World ZK / Identity & Privacy) |
| **Prize** | **$10,000 XLM prize pool** across the top 5 projects (1st = $5,000). ⚠️ Mid-tier (2nd–4th) splits are an estimate, not confirmed — do not quote them as fact. |
| **Deadline** | **Jun 29, 2026 — TOMORROW** |
| **Submission URL** | https://dorahacks.io/hackathon/stellar-hacks-zk |
| **GitHub repo** | https://github.com/aggreyeric/veritas-zk |
| **Tests** | **7/7 passing** (3 sandbox + 3 verify_real + 1 new ZK-lifecycle test). _Note: some older docs say "6/6" — that's stale; the repo now has 7._ |
| **Demo** | `./scripts/demo.sh` — end-to-end ZK proof verified on-chain |

---

## ⏱️ The 10-Minute Submit Flow

1. **Verify locally (2 min):**
   ```bash
   cd ~/hiclaw_manager/builds/veritas-zk
   ./scripts/demo.sh            # end-to-end: must finish all-green
   cd soroban/contracts/veritas-verifier && cargo test   # 7/7
   ```
2. **Open** https://dorahacks.io/hackathon/stellar-hacks-zk — if it 404s, search DoraHacks for "stellar zk" and use the real URL.
3. **Connect wallet** (Freighter / Albedo) when prompted — only needed to submit.
4. Click **"Submit Project"** (top-right or in the hackathon banner).
5. **Paste each block** from the §"Copy-Paste Form Fields" below into the matching field.
6. **Upload** the screenshot + paste the demo/repo links.
7. **Final gate:** Eric's explicit OK → click **Submit**.
8. **Screenshot the confirmation page** (proof + timestamp) and send it back.

---

## 📋 Copy-Paste Form Fields

> Each block is self-contained and within typical field limits. Paste verbatim.

### 1. Project Name
```
Veritas ZK — Zero-Knowledge Credential Verifier
```
*(Short form if the field is tiny: `Veritas ZK`)*

### 2. One-line Tagline (≤ 255 chars)
```
Prove credentials without revealing them — circom + Groth16 proofs, verified on-chain by a real BN254 pairing inside a Soroban contract.
```
*Shorter fallback (~140 chars) if the field is tighter:*
```
A ZK credential-compliance layer for Stellar: prove "I'm 18+", "jurisdiction-allowed", or "valid owner" — verified on-chain via BN254.
```

### 3. Project Description (paste all 3 paragraphs)

```
Veritas ZK is a privacy-preserving credential-compliance layer for Stellar / Soroban. A holder generates a Groth16 zero-knowledge proof that a derived predicate about their credential holds — "I'm 18+", "this credential is mine and valid", "my country is in the allow-set" — and a Soroban smart contract verifies that proof on-chain via a real BN254 pairing. The verifier learns only that the predicate holds; the date of birth, country, name, and underlying document never leave the holder's device.

Why this matters: KYC, AML, and sanctions compliance is the single biggest barrier to real-world on-chain payments. Today, proving you may transact means uploading a passport to a centralized oracle — a privacy and custody nightmare. ZK credentials replace document disclosure with cryptographic proof: the contract learns "this person is 18+", never their date of birth. An invalid predicate makes the circuit unsatisfiable — no proof can ever exist — so forgery is impossible, not merely discouraged.

How it works: an issuer signs a credential claim with EdDSA-Poseidon over BabyJubJub. The holder derives a predicate and produces a Groth16 proof in circom on top of circomlib (Poseidon hash, BabyJubJub, Groth16 over BN254). Because Stellar has no BN254 precompile, Veritas implements the full Groth16 verification — miller-loop and final-exponentiation — inside a no_std Soroban contract using ark-bn254, exposing verify_for(circuit_id, proof, public) and verify_credential (proof + issuer-pubkey match + Merkle-root match + nullifier record for double-spend protection). One signed credential yields reusable proofs across dApps.
```
*If the form has a higher word limit, append the "How it works (4 steps)" + "Innovation" blocks below.*

### 4. What It Does (bulleted — if a separate field)
```
- AgeGte — prove age ≥ threshold from a private date-of-birth, without revealing the DOB.
- ValidOwner — prove a credential was issuer-signed and is owned by the prover; emits a double-spend nullifier.
- JurisdictionAllowed — prove the holder's country is in an allow-set, via a Poseidon Merkle-membership proof against an on-chain root (e.g. sanctions allow-list).
- CredentialAge (flagship) — an issuer-signed credential whose private age ≥ threshold, emitting a nullifier.
- A gated action (faucet unlock / transfer) unlocks only after the on-chain BN254 pairing returns true. A tampered or replayed proof is rejected.
```

### 5. How We Built It
```
Circom circuits on top of circomlib (Poseidon hash, BabyJubJub EdDSA, Groth16 over BN254). Groth16 trusted setup + proof generation via snarkjs. The proofs are encoded into big-endian byte arrays and verified inside a #![no_std] Rust Soroban contract using ark-bn254, which implements the full Groth16 verification (miller-loop + final-exponentiation) because Stellar has no BN254 precompile — ~73 KB of WASM. Off-chain issuer (BabyJub EdDSA-Poseidon signing) and prover (witness + Groth16 proof + byte encoding) services in Node, plus a parallel pure-Python toolchain (issuer/witness/proof/verify) as an independent cross-check. Correctness is proven two ways: the shared pairing core is unit-tested against real snarkjs proofs, and a Soroban sandbox test deploys the contract and verifies the identical proofs on-chain. The deploy script submits the same proof bytes to Stellar testnet (verify_for(...) → true).
```

### 6. Tech Stack
```
Rust · circom · snarkjs · Groth16 (BN254) · Soroban (Stellar) · TypeScript · circomlib (Poseidon / BabyJubJub / EdDSA) · ark-bn254
```

### 7. Innovation / What's Unique (the ZK angle)
```
The submission's core is a deployed Soroban contract that verifies REAL Groth16 proofs by computing BN254 pairings in WASM — no BN254 precompile exists on Stellar, so we implemented the full miller-loop + final-exponentiation in the contract itself. It is not a stub or a fake "verified" flag. Compliance-as-a-private-predicate is a fresh framing on Stellar: one issuer-signed credential yields reusable age, jurisdiction, and ownership proofs across dApps, with on-chain double-spend protection via per-use nullifiers. One architecture lands three real-world use-cases at once — identity verification without document exposure, private payments, and confidential tokens.
```

### 8. GitHub Repository URL
```
https://github.com/aggreyeric/veritas-zk
```

### 9. Demo Video URL
```
[ERIC: add link before submitting]
```
> Record 2–3 min: run `./scripts/demo.sh` on screen (the tampered-proof rejection is the money shot for judges), then `deploy_testnet.sh` returning `true`. Script outline in `DEMO_VIDEO_SCRIPT.md`.

### 10. Cover Image / Screenshot
```
Upload: docs/demo-screenshot.png
```

---

## 🎬 Demo Instructions — `./scripts/demo.sh`

**How to run:**
```bash
cd ~/hiclaw_manager/builds/veritas-zk
./scripts/demo.sh
```
**Prereqs:** Node 18+, `circom` 2.x, `snarkjs`, Rust + `wasm32v1-none` target, `stellar` CLI. The script checks for all of them and fails fast if any are missing.

**What it shows, in order:**
1. **Issuer signs** demo credentials — BabyJub EdDSA-Poseidon (`scripts/gen_test_inputs.js`).
2. **Compile circuits** — R1CS + witness WASM for AgeGte / ValidOwner / JurisdictionAllowed.
3. **Groth16 trusted setup + proof generation + OFF-CHAIN verify** via snarkjs (`verify_all.sh`) → `OK!`.
4. **Encode proofs → on-chain bytes** (`proof.bin` / `public.bin` / `vk.bin` per circuit).
5. **Build the Soroban verifier** (BN254 pairing in WASM, ~73 KB).
6. **ON-CHAIN verify in the Soroban sandbox** — AgeGte unlocks the faucet, ValidOwner enforces double-spend protection, JurisdictionAllowed binds to the posted Merkle root.
7. **Tampered credential REJECTED** — threshold bumped 18→21 and a cross-circuit proof both fail. ✅

> Expect ~73 KB wasm and all-green output. The sandbox uses the **identical** WASM that `deploy_testnet.sh` pushes to testnet — so the on-chain story is reproducible without spending XLM.

**Optional testnet proof (real submit):**
```bash
export STELLAR_ADMIN_SECRET="<funded testnet secret>"
bash scripts/deploy_testnet.sh   # verify_for(...) -> true  on Stellar testnet
```

---

## ✅ Pre-Submit Checklist (tick every box)

### Code & Tests
- [ ] `./scripts/demo.sh` runs clean end-to-end (all-green, tampered proof rejected)
- [ ] `cargo test` → **7/7 passing** (in `soroban/contracts/veritas-verifier`)
- [ ] No `TODO` / `FIXME` / `unimplemented!()` / stub markers in shipped circuits or contract

### Docs & Assets
- [ ] `README.md` renders (badges + flow diagram) on GitHub
- [ ] `docs/demo-screenshot.png` looks good — upload as cover image
- [ ] `docs/demo.html` renders (link it if the form wants a hosted demo)
- [ ] Demo video recorded → link pasted into field 9

### DoraHacks Form
- [ ] Project name (field 1) pasted
- [ ] Tagline ≤ 255 chars (field 2) pasted
- [ ] Description (field 3) pasted
- [ ] GitHub repo (field 8) pasted
- [ ] Screenshot (field 10) uploaded
- [ ] Track = **Stellar ZK #15** selected
- [ ] Team members / contacts filled

### Final Gate
- [ ] **Eric's explicit approval** before clicking Submit
- [ ] Confirmation page **screenshotted** (proof + timestamp) after submit → send it back

---

## 🛠️ Troubleshooting

**If submit fails on repo size (~101 MB):** circom build artifacts (`.r1cs`, `.wasm`, powers-of-tau, witnesses) are in git history. These are reproducible build outputs, not source. Options, easiest first:
- **Shallow clone works as-is** — if DoraHacks only fetches the latest, submit as-is with a note.
- **`git filter-repo`** to strip build globs + force-push (see `PRE_SUBMIT_CHECKLIST.md` for the exact command). Add the globs to `.gitignore` so they don't return.
- **Fresh squashed repo** as a last resort.
> ⚠️ If you run any history rewrite, **note it and ping hack_3** — don't redo from scratch, and do NOT touch secrets.

**If the DoraHacks page is JS-rendered / blank:** it's normal — curl can't scrape it. Open in a real browser, search "stellar zk", use the live URL. Cloudflare may challenge automated requests.

**If `cargo test` shows 6 not 7:** you're on a stale checkout. The 7th test (`zk_lifecycle.rs`) is the new ZK-lifecycle test — `git pull` / confirm the file exists in `soroban/contracts/veritas-verifier/tests/`.

---

## 🔗 Quick Links

- **Repo:** https://github.com/aggreyeric/veritas-zk
- **Submit at:** https://dorahacks.io/hackathon/stellar-hacks-zk
- **Local dir:** `~/hiclaw_manager/builds/veritas-zk`
- **Demo:** `./scripts/demo.sh`
- **Tests:** `cd soroban/contracts/veritas-verifier && cargo test` (7/7)
- **Supporting docs:** `DORAHACKS_SUBMISSION.md`, `SUBMISSION_FORM_FIELDS.md`, `DEMO_VIDEO_SCRIPT.md`, `README.md`

---

_Prepared by **hack_3** for the Jun 29 DoraHacks submit. Not pushed to git, not submitted to any portal, no secrets touched._
