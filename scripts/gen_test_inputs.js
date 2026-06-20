// Generates valid sample inputs for the three Veritas circuits using circomlibjs.
// Run:  node scripts/gen_test_inputs.js
//   -> circuits/test_inputs.json   (combined: { ageGte, jurisdictionAllowed, validOwner })
//   -> build/age_gte_input.json, build/jurisdiction_allowed_input.json,
//      build/valid_owner_input.json   (per-circuit files, ready for `snarkjs wc`)
//
// All keys are demo/test values. DO NOT use these keys in production.

const { buildEddsa, buildPoseidon } = require("circomlibjs");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const CIRCUITS = path.join(ROOT, "circuits");
const BUILD = path.join(CIRCUITS, "build");

const ensureDir = (d) => { if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true }); };
const writeJSON = (file, obj) => fs.writeFileSync(file, JSON.stringify(obj, null, 2) + "\n");

(async () => {
  const poseidon = await buildPoseidon();
  const F = poseidon.F;                       // BN254 scalar field (== BabyJub base field)
  // toStr accepts EITHER a field-element object (from poseidon()/eddsa) OR a raw bigint.
  const toStr = (e) => (typeof e === "bigint" ? e.toString() : F.toObject(e).toString());
  const pHash = (arr) => BigInt(F.toObject(poseidon(arr.map((x) => BigInt(x))))); // -> reduced bigint

  // --------------------------------------------------------------------------
  // 1) AgeGte  — DOB 2003-06-15, "now" 2026-06-20, threshold 18  => age 23 (>=18)
  //    now_day(20) >= dob_day(15) and same month  => notHadBday = 0  => age = 2026-2003 = 23
  // --------------------------------------------------------------------------
  const ageGte = {
    dob_year: "2003",
    dob_month: "6",
    dob_day: "15",
    salt: "777777777777777777",
    now_year: "2026",
    now_month: "6",
    now_day: "20",
    threshold: "18",
  };
  const ageCommit = pHash([
    BigInt(ageGte.dob_year), BigInt(ageGte.dob_month),
    BigInt(ageGte.dob_day), BigInt(ageGte.salt),
  ]);

  // --------------------------------------------------------------------------
  // 2) JurisdictionAllowed — depth-16 Poseidon Merkle tree of allowed countries
  //    ISO-3166 numeric: US=840, CA=124, GB=826, DE=276, JP=392, KR=410, NL=528, ES=724
  //    We prove membership of CA (124) without revealing it.
  // --------------------------------------------------------------------------
  const DEPTH = 16;
  const SIZE = 1 << DEPTH;
  const countries = [840, 124, 826, 276, 392, 410, 528, 724];
  const target = 124;                         // Canada
  const targetIdx = countries.indexOf(target);

  // bottom level: Poseidon(country) at the first |countries| slots, 0 elsewhere
  const level = new Array(SIZE).fill(0n);
  countries.forEach((c, i) => { level[i] = pHash([BigInt(c)]); });
  const countryHashStr = toStr(level[targetIdx]);

  // walk the path for `targetIdx`, collecting siblings + direction bits
  const pathElements = [];
  const pathIndices = [];
  let idx = targetIdx;
  let cur = level.slice();
  for (let lvl = 0; lvl < DEPTH; lvl++) {
    const sib = idx ^ 1;
    pathElements.push(toStr(cur[sib]));
    pathIndices.push(String(idx & 1));        // 0 => current is LEFT child (matches lib)
    // hash pairs up to the next level
    const next = new Array(cur.length >> 1);
    for (let i = 0, j = 0; i < cur.length; i += 2, j++) {
      next[j] = pHash([cur[i], cur[i + 1]]);
    }
    cur = next;
    idx >>= 1;
  }
  const merkleRootStr = toStr(cur[0]);

  const jurisdictionAllowed = {
    country_hash: countryHashStr,
    pathElements,
    pathIndices,
    merkleRoot: merkleRootStr,
  };

  // --------------------------------------------------------------------------
  // 3) ValidOwner — BabyJub EdDSA over a Poseidon claim_hash + per-use nullifier
  // --------------------------------------------------------------------------
  const eddsa = await buildEddsa();
  // TEST-ONLY issuer private key (clearly marked DO NOT USE IN PROD)
  const prv = Buffer.from("0000000000000000000000000000000000000000000000000000000000000007", "hex");
  const pub = eddsa.prv2pub(prv);             // [Ax, Ay] on BabyJub
  const issuerAx = toStr(pub[0]);
  const issuerAy = toStr(pub[1]);

  // claim = { type: 1001, value: 42 }  ->  claim_hash = Poseidon(1001, 42)
  const claimHashFE = poseidon([1001n, 42n]);   // field-element object (the signed message M)
  const claimHashStr = toStr(claimHashFE);
  const claimHashBig = F.toObject(claimHashFE); // bigint for re-hashing the nullifier
  const nonce = 0xb01dcafe1n;                   // per-use randomizer

  const sig = eddsa.signPoseidon(prv, claimHashFE);
  const ok = eddsa.verifyPoseidon(claimHashFE, sig, pub);
  if (!ok) throw new Error("EdDSA self-verify failed — sig invalid");

  const sigR8x = toStr(sig.R8[0]);
  const sigR8y = toStr(sig.R8[1]);
  const sigS = sig.S.toString();

  // nullifier = Poseidon(claim_hash, nonce)
  const nullifier = pHash([claimHashBig, nonce]);
  const nullifierStr = toStr(nullifier);

  const validOwner = {
    claim_hash: claimHashStr,
    nonce: nonce.toString(),
    sigR8x,
    sigR8y,
    sigS,
    issuerAx,
    issuerAy,
  };

  // --------------------------------------------------------------------------
  // write outputs
  // --------------------------------------------------------------------------
  ensureDir(BUILD);
  const combined = {
    _comment: "Veritas sample circuit inputs (TEST values, not for production).",
    _generatedBy: "scripts/gen_test_inputs.js (circomlibjs)",
    ageGte,
    jurisdictionAllowed,
    validOwner,
    expected: {
      ageGte: { commitment: toStr(ageCommit), ageGte: "1", age: 23 },
      jurisdictionAllowed: { computedRoot: merkleRootStr, allowed: "1" },
      validOwner: { nullifier: nullifierStr, verified: "1" },
    },
  };
  writeJSON(path.join(CIRCUITS, "test_inputs.json"), combined);

  // per-circuit clean input files for `snarkjs wc` (no extra keys)
  writeJSON(path.join(BUILD, "age_gte_input.json"), ageGte);
  writeJSON(path.join(BUILD, "jurisdiction_allowed_input.json"), jurisdictionAllowed);
  writeJSON(path.join(BUILD, "valid_owner_input.json"), validOwner);

  console.log("Wrote circuits/test_inputs.json");
  console.log("Wrote build/age_gte_input.json, build/jurisdiction_allowed_input.json, build/valid_owner_input.json");
  console.log("---- expected outputs ----");
  console.log("ageGte.age           =", 23);
  console.log("ageGte.commitment    =", toStr(ageCommit));
  console.log("jurisdiction root    =", merkleRootStr);
  console.log("validOwner.nullifier =", nullifierStr);
  console.log("issuer pubkey        =", issuerAx.slice(0, 12) + "..., " + issuerAy.slice(0, 12) + "...");
})().catch((e) => { console.error(e); process.exit(1); });
