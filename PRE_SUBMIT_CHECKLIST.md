# Pre-Submission Checklist — Veritas ZK

**Hackathon:** Stellar Hacks ZK · DoraHacks
**Submission URL:** https://dorahacks.io/hackathon/stellar-hacks-zk
**Repo:** https://github.com/aggreyeric/veritas-zk
**Prepared:** 2026-06-22 by hack_1

> Run through every box before clicking submit. Do **not** submit without Eric's explicit go-ahead.

---

## Code & Tests

- [ ] All tests pass (`cargo test`) — submission doc claims 6/6 green; re-run to confirm before submit
- [ ] `cargo build --release` clean (no warnings worth scrubbing)
- [ ] No `TODO` / `FIXME` / `unimplemented!()` / stub markers in shipped circuits or contract
- [ ] `scripts/demo.sh` runs end-to-end locally one more time (signed cred → Groth16 proof → on-chain verify → gated faucet → tampered-proof reject)

## Docs

- [ ] `README.md` is complete — project overview, one-liner, how-it-works, circuits section, run instructions, tech stack, demo link
- [ ] `docs/demo.html` exists and renders cleanly (✅ present, 13.5 KB)
- [ ] `docs/demo-screenshot.png` available and looks good (✅ present, 383 KB) — open it, eyeball it
- [ ] `docs/architecture-diagram.txt` referenced where relevant (✅ present)
- [ ] `DORAHACKS_SUBMISSION.md` copy-paste-ready (✅ — verify one-liner / description still match latest code)

## Repo Hygiene

- [ ] GitHub repo is **public** — `github.com/aggreyeric/veritas-zk` reachable logged-out
- [ ] **No secrets in repo** — scan for: `.env`, private keys, powers-of-tau ceremony secrets, issuer signing keys, testnet account secrets, `SECRET`, `MNEMONIC`. Run: `git log -p | grep -iE 'private|secret|mnemonic|seed' | head`
- [ ] `.gitignore` covers `target/`, `*.r1cs` (going forward), `.env*`, `node_modules/`
- [ ] LICENSE file present (MIT/Apache — check what hack_3 set)
- [ ] Tagged release or pinned commit marked "submission" so judges see a stable ref

## DoraHacks Form

- [ ] `SUBMISSION_FORM_FIELDS.md` filled — all required DoraHacks fields populated (project name, one-liner, description, tech stack, demo URL, GitHub, team)
- [ ] Past one-liner, description, tech stack from `DORAHACKS_SUBMISSION.md` into the form
- [ ] Upload screenshot `docs/demo-screenshot.png` where the form asks for a cover image
- [ ] Link demo (`docs/demo.html`) — if DoraHacks wants a hosted URL, deploy `demo.html` (GitHub Pages / Netlify) and use that
- [ ] Team members / contacts filled

## Git History Warning (known issue)

- [ ] **`git filter-repo` run** — repo is ~101 MB due to committed circom build artifacts (`.r1cs`, `.wasm`, powers-of-tau, witnesses) in history. `git clone` is slow and may trip DoraHacks/GitHub size warnings.
  - Recommended before submit:
    ```bash
    git clone --mirror https://github.com/aggreyeric/veritas-zk vzk-mirror
    cd vzk-mirror
    git filter-repo \
      --path-glob '*.r1cs' \
      --path-glob '*.wasm' \
      --path-glob '*.ptau' \
      --path-glob 'powersOfTau*' \
      --path-glob '*.wtns' \
      --invert-paths
    git push --force
    ```
  - Add the above globs to `.gitignore` so they don't come back.
  - If filter-repo is too risky / time-cramped, fall back to a fresh squashed repo + force-push, or just submit as-is with a note (shallow-clone works). Do **not** ship a broken history.

## Final Gate

- [ ] Eric's explicit approval before clicking submit
- [ ] Screenshot the confirmation page after submit (proof of submission + timestamp)

---

_Status: pre-check. Nothing submitted yet._
