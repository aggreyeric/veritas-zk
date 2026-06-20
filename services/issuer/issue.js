#!/usr/bin/env node
// =============================================================================
// Veritas Issuer / Attester
// =============================================================================
// An off-chain authority (KYC provider, government, accreditation body) that
// signs a credential *claim* with EdDSA-Poseidon over BabyJubJub. The holder
// keeps the signed credential private and later proves a DERIVED predicate
// (age ≥ 18, jurisdiction allowed, valid-owner) in zero knowledge.
//
// The claim is hashed with Poseidon:   m = Poseidon(age, holderSecret)
// The issuer signs m. The signature (R8.x, R8.y, S) + issuer pubkey (Ax, Ay)
// become the *private* inputs (signature) and *public* inputs (pubkey) of the
// ValidOwner / CredentialAge circuits.
//
// THIS IS A DEMO ISSUER. Keys are generated fresh each run. NEVER use in prod.
//
// Usage:  node services/issuer/issue.js [age] [threshold]
//   -> prints { issuerAx, issuerAy, holderSecret, age, signature }

const { buildEddsa, buildPoseidon } = require("circomlibjs");

(async () => {
  const eddsa = await buildEddsa();
  const poseidon = await buildPoseidon();
  const F = poseidon.F;
  const toStr = (e) =>
    typeof e === "bigint" ? e.toString() : F.toObject(e).toString();

  const age = parseInt(process.argv[2] || "23", 10);
  const threshold = parseInt(process.argv[3] || "18", 10);

  // 1. Fresh BabyJub issuer keypair (demo only).
  const issuerPriv = "veritas-demo-issuer-" + Date.now();
  const issuerPub = eddsa.prv2pub(issuerPriv);

  // 2. Per-credential holder secret (nullifier seed) — given to the holder.
  const holderSecret = eddsa.prv2pub("holder-" + Math.random())[0]; // field element

  // 3. Claim message: m = Poseidon(age, holderSecret). Issuer signs exactly m.
  const mBuf = poseidon([F.e(age), F.e(holderSecret)]);
  const m = F.toObject(mBuf);

  // 4. Sign.
  const sig = eddsa.signPoseidon(issuerPriv, m);

  const out = {
    _note: "DEMO issuer output. Keys are non-production. Do not reuse.",
    claim: { age, threshold },
    issuerAx: toStr(issuerPub[0]),
    issuerAy: toStr(issuerPub[1]),
    holderSecret: toStr(holderSecret),
    signature: { R8x: toStr(sig.R8[0]), R8y: toStr(sig.R8[1]), S: toStr(sig.S) },
    signedMessage: toStr(m),
    _onchain: {
      // Register these with the Soroban contract:  set_issuer(ax, ay)
      set_issuer_ax_hex: BigInt(toStr(issuerPub[0])).toString(16).padStart(64, "0"),
      set_issuer_ay_hex: BigInt(toStr(issuerPub[1])).toString(16).padStart(64, "0"),
    },
  };
  console.log(JSON.stringify(out, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
