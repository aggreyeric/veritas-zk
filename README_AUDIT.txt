README AUDIT — veritas-zk/README.md
=====================================
1. FIRST 100 CHARS: Bad order — opens with a wall of 9 badge tags before any
   project description. A zero-context reader sees shields.io URLs, not the
   project. The real one-liner ("A ZK credential-compliance layer for Stellar
   / Soroban") only appears ~400 chars in. Recommend moving the H1 + tagline
   ABOVE the badges.

2. IMAGE REFERENCES: BROKEN. README cites:
     docs/demo-output.png        -> MISSING
     docs/architecture.png       -> MISSING
   Real docs/ contents = only `architecture-diagram.txt`. The Screenshots
   table will render two broken-image icons. Fix: add the PNGs or drop section.

3. MARKDOWN LINKS: All non-image links resolve (LICENSE, SUBMISSION.md,
   Dockerfile, scripts/demo.sh, deploy_testnet.sh, veritas-verifier/). OK.

4. TEST COUNT: "6 tests pass" is ACCURATE — 6 #[test] fns across
   verify_real.rs + sandbox.rs. Badge says "6 passed". Consistent.

5. TODO/FIXME/PLACEHOLDER: NONE found in README. Clean.

ACTION NEEDED: (a) move title above badges, (b) fix/remove the 2 broken PNGs.
