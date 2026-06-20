#!/usr/bin/env node
// =============================================================================
// Veritas Prover  (client-side / off-chain)
// =============================================================================
// A holder runs this to generate a zero-knowledge proof of a derived predicate
// from their signed credential, WITHOUT revealing the credential itself. The
// proof + public inputs are encoded into the byte format the Soroban verifier
// consumes, ready to submit on-chain.
//
// Pipeline:  inputs (gen_test_inputs.js) -> witness (snarkjs wc) ->
//            Groth16 proof (snarkjs groth16 prove) -> bytes (proof_to_bytes.js)
//
// Usage:  node services/prover/prove.js <circuit>
//   circuit ∈ AgeGte | ValidOwner | JurisdictionAllowed | CredentialAge
//
// Prereq: circuits compiled + zkeys built (run scripts/verify_all.sh once, or
// scripts/demo.sh which does everything).

const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "..");
const CIRC = path.join(ROOT, "circuits");
const BUILD = path.join(CIRC, "build");
const ZK = path.join(BUILD, "zkeys");
const sh = (file, args, opts = {}) =>
  execFileSync(file, args, { stdio: "inherit", cwd: ROOT, ...opts });

const circuit = process.argv[2] || "AgeGte";
const CIRCUITS = ["AgeGte", "ValidOwner", "JurisdictionAllowed", "CredentialAge"];
if (!CIRCUITS.includes(circuit)) {
  console.error(`unknown circuit '${circuit}'. one of: ${CIRCUITS.join(", ")}`);
  process.exit(1);
}

// 1. Make sure sample inputs exist.
const inputsByCircuit = {
  AgeGte: path.join(BUILD, "age_gte_input.json"),
  ValidOwner: path.join(BUILD, "valid_owner_input.json"),
  JurisdictionAllowed: path.join(BUILD, "jurisdiction_allowed_input.json"),
  // CredentialAge reuses the ValidOwner key material in the demo build.
  CredentialAge: path.join(BUILD, "valid_owner_input.json"),
};
const input = inputsByCircuit[circuit];
if (!fs.existsSync(input)) {
  console.log("▶ generating sample credential inputs (gen_test_inputs.js)…");
  sh("node", ["scripts/gen_test_inputs.js"]);
}

// 2. Proving key must exist (built by verify_all.sh / demo.sh).
const zkey = path.join(ZK, `${circuit}_final.zkey`);
if (!fs.existsSync(zkey)) {
  console.error(`missing proving key ${zkey}. Run scripts/demo.sh first.`);
  process.exit(1);
}

// 3. Witness calculation.
const wasm = path.join(BUILD, `${circuit}_js`, `${circuit}.wasm`);
const wtns = path.join(ZK, `${circuit}_witness.wtns`);
console.log(`▶ [${circuit}] witness…`);
execFileSync("snarkjs", ["wc", wasm, input, wtns], { stdio: "inherit", cwd: CIRC });

// 4. Groth16 proof.
const proofJson = path.join(ZK, `${circuit}_proof.json`);
const publicJson = path.join(ZK, `${circuit}_public.json`);
console.log(`▶ [${circuit}] Groth16 proof…`);
execFileSync(
  "snarkjs",
  ["groth16", "prove", zkey, wtns, proofJson, publicJson],
  { stdio: "inherit", cwd: CIRC }
);

// 5. Off-chain sanity check (must print "OK!").
console.log(`▶ [${circuit}] off-chain verify…`);
execFileSync(
  "snarkjs",
  ["groth16", "verify", path.join(ZK, `${circuit}_vkey.json`), publicJson, proofJson],
  { stdio: "inherit", cwd: CIRC }
);

// 6. Encode for the on-chain contract.
console.log(`▶ [${circuit}] encode on-chain bytes…`);
sh("node", ["scripts/proof_to_bytes.js", circuit]);

console.log(`\n✓ proof ready for ${circuit}.`);
console.log(`  submit to Soroban:  verify_for(circuitId, proof.bin, public.bin)`);
console.log(`  circuitId: AgeGte=0 ValidOwner=1 JurisdictionAllowed=2 CredentialAge=3`);
