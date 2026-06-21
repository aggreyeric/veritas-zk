# Veritas — Submission Guide for Eric

**Hackathon:** Stellar Hacks ZK · DoraHacks
**Submit at:** **https://dorahacks.io/hackathon/stellar-hacks-zk**
**Prize:** $10K XLM · **Deadline: Jun 29** · ✋ You click submit — nothing is auto-submitted.

> All field copy below is paste-ready and within DoraHacks limits. Sourced from `SUBMISSION_FORM_FIELDS.md`.

---

## 1. Paste these fields into the form

### Project Name
```
Veritas — Privacy-Preserving Credential Verifier on Stellar
```

### Tagline (≤255 chars — this is ~243)
```
Prove you're compliant — without revealing the document. Veritas is a ZK credential-compliance layer for Soroban: holders generate Groth16 proofs of derived predicates and a Soroban contract verifies them on-chain via a real BN254 pairing.
```
_(Tighter field? Use the ~170-char fallback in `SUBMISSION_FORM_FIELDS.md` §2.)_

### Description (~720 words, within 500–800)
Paste the full block from `SUBMISSION_FORM_FIELDS.md` **§3** verbatim.
_Trim the "Honesty" paragraph first if the form's limit is tighter._

### GitHub Repo URL
```
https://github.com/aggreyeric/veritas-zk
```
⚠️ Confirm it's **public** and the README renders (badges + flow diagram) before pasting.

### Demo Video URL
```
[Eric: paste your Loom / YouTube / Bilibili link here]
```

---

## 2. Track suggestion

**Pick whichever DoraHacks track name matches, in this priority order:**
1. `Real-World ZK — Identity & Privacy` ← primary
2. `ZK for Identity & Compliance`
3. `Privacy & Zero-Knowledge`
4. `DeFi / Payments Infrastructure`

**One-line rationale (if the form asks):** Veritas turns KYC/AML/sanctions compliance — the #1 barrier to real-world on-chain payments — into a privacy-preserving on-chain primitive via ZK proofs verified on Soroban. One design hits identity verification, private payments, and confidential tokens.

---

## 3. Demo video — record using the existing script

Use **`DEMO_VIDEO_SCRIPT.md`** (in the repo) as your shot list — it's a ready 3-min script: screen-capture + voiceover, one terminal, runs entirely in the **Soroban sandbox** (no testnet account, no funds needed).

**Before recording:** `cd veritas-zk && npm install && rustup target add wasm32v1-none`, then run `bash scripts/demo.sh` once to pre-build artifacts.

**Money shot for judges (~line 4 of the demo):** the **tampered-proof rejection**. Plus `deploy_testnet.sh` returning `true`. Aim for 2–3 min.

---

## 4. Pre-submit checklist

- [ ] Repo `aggreyeric/veritas-zk` is **public**, README renders (badges + diagram)
- [ ] All 6 tests pass: `cd soroban/contracts/veritas-verifier && cargo test`
- [ ] `scripts/demo.sh` runs clean end-to-end
- [ ] Demo video recorded → link pasted into the form
- [ ] Tagline pasted verbatim (≤255 chars)
- [ ] Description within the form's word/char limit
- [ ] **Final go/no-go from Eric before clicking submit**

---

_Prepared by hack_2. Not submitted anywhere — awaiting Eric's approval._
