#!/usr/bin/env node
// =============================================================================
// proof_to_bytes.js — bridge snarkjs JSON artifacts → Veritas contract bytes.
// =============================================================================
// Reads {circuit}_vkey.json, {circuit}_proof.json, {circuit}_public.json and
// emits the big-endian byte blobs the Soroban verifier expects:
//   proof.bin  (256 B): A.x A.y | B.x.c0 B.x.c1 B.y.c0 B.y.c1 | C.x C.y
//   public.bin       : nPublic × 32 B (decimal strings, BE)
//   vk.bin           : α(2) β(4) γ(4) δ(4) nPublic(1) IC[(n+1)*2]
//
// Usage: node scripts/proof_to_bytes.js [circuit]   (default: AgeGte)
//   circuit ∈ AgeGte | ValidOwner | JurisdictionAllowed | CredentialAge
// Writes circuits/build/zkeys/{circuit}_{proof,public,vk}.bin and prints hex.

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const ZK = path.join(ROOT, "circuits", "build", "zkeys");

const circuit = process.argv[2] || "AgeGte";
const read = (f) => JSON.parse(fs.readFileSync(path.join(ZK, f), "utf8"));
const write = (f, buf) => fs.writeFileSync(path.join(ZK, f), buf);

// decimal-string → 32-byte big-endian Buffer
const b32 = (s) => {
  let hex = BigInt(s).toString(16);
  hex = "0".repeat(64 - hex.length) + hex; // left-pad to 64 hex chars
  return Buffer.from(hex, "hex");
};

// snarkjs G1 = [x,y,1]  -> 64 B
const g1 = (v) => Buffer.concat([b32(v[0]), b32(v[1])]);
// snarkjs G2 = [[x.c0,x.c1],[y.c0,y.c1],[1,0]]  -> 128 B  (c0 FIRST)
const g2 = (v) =>
  Buffer.concat([b32(v[0][0]), b32(v[0][1]), b32(v[1][0]), b32(v[1][1])]);

const vk = read(`${circuit}_vkey.json`);
const proof = read(`${circuit}_proof.json`);
const pub = read(`${circuit}_public.json`);

// proof.bin
const proofBin = Buffer.concat([
  g1(proof.pi_a),
  g2(proof.pi_b),
  g1(proof.pi_c),
]);
write(`${circuit}_proof.bin`, proofBin);

// public.bin
const pubBin = Buffer.concat(pub.map(b32));
write(`${circuit}_public.bin`, pubBin);

// vk.bin
const vkBin = Buffer.concat([
  g1(vk.vk_alpha_1),
  g2(vk.vk_beta_2),
  g2(vk.vk_gamma_2),
  g2(vk.vk_delta_2),
  Buffer.from([pub.length]), // nPublic as 1 byte
  ...vk.IC.map(g1),
]);
write(`${circuit}_vk.bin`, vkBin);

const hex = (b) => b.toString("hex");
console.log(`✓ ${circuit}: wrote proof.bin (${proofBin.length} B), ` +
            `public.bin (${pubBin.length} B), vk.bin (${vkBin.length} B)`);
console.log(`  nPublic=${pub.length}`);
console.log(`  proof.hex=${hex(proofBin)}`);
console.log(`  public.hex=${hex(pubBin)}`);
