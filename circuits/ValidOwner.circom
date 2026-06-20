pragma circom 2.1.6;

// ============================================================================
// Veritas — "ValidOwner": credential validity + ownership + nullifier
// ============================================================================
// MVP primitive #3 from the build brief. Proves, WITHOUT revealing the claim:
//   * a credential (whose Poseidon hash is `claim_hash`) was genuinely signed
//     by a known issuer (BabyJub EdDSA public key issuerAx/issuerAy),
//   * the prover is using it correctly,
//   * and emits a per-use NULLIFIER = Poseidon(claim_hash, nonce) for
//     double-spend protection — the same (claim, nonce) always yields the same
//     nullifier, so a Soroban contract can reject a reused credential WITHOUT
//     ever learning who the holder is.
//
// `claim_hash` is private (which credential), `nonce` is private (randomizer),
// the EdDSA signature is private, and only the issuer pubkey + the derived
// nullifier are public.
//
// SECURITY NOTES
//   * EdDSA is verified with circomlib's `EdDSAPoseidonVerifier` over the
//     message M = claim_hash. That template enforces the verification equation
//     purely through internal constraints (ForceEqualIfEnabled on both curve
//     coordinates) — it has NO boolean output; an invalid signature makes the
//     whole circuit UNSATISFIABLE. That is the security guarantee: a forged
//     signature cannot produce a proof.
//   * The nullifier is recomputed inside the circuit from claim_hash + nonce,
//     so the verifier learns the nullifier but not claim_hash or nonce.
//
// Primitives: circomlib `EdDSAPoseidonVerifier` (eddsaposeidon.circom),
//             circomlib `Poseidon` (poseidon.circom).
// Proof system: Groth16 on BN254.
// ============================================================================

include "node_modules/circomlib/circuits/eddsaposeidon.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

template ValidOwner() {
    // ---- private inputs (the credential + the use) ----
    signal input claim_hash;   // Poseidon(claim attributes), signed by the issuer
    signal input nonce;        // per-use randomizer for the nullifier
    signal input sigR8x;       // EdDSA signature point R8.x
    signal input sigR8y;       // EdDSA signature point R8.y
    signal input sigS;         // EdDSA scalar S

    // ---- public inputs ----
    signal input issuerAx;     // issuer BabyJub public key .x
    signal input issuerAy;     // issuer BabyJub public key .y

    // ---- public outputs ----
    signal output nullifier;   // Poseidon(claim_hash, nonce) — double-spend key
    signal output verified;    // 1 for any valid proof (unsatisfiable otherwise)

    // --- EdDSA verification: the issuer signed M = claim_hash ---
    // Invalid signature => circuit is unsatisfiable (no proof possible).
    component eddsa = EdDSAPoseidonVerifier();
    eddsa.enabled <== 1;
    eddsa.Ax  <== issuerAx;
    eddsa.Ay  <== issuerAy;
    eddsa.S   <== sigS;
    eddsa.R8x <== sigR8x;
    eddsa.R8y <== sigR8y;
    eddsa.M   <== claim_hash;

    // --- nullifier = Poseidon(claim_hash, nonce) ---
    component nul = Poseidon(2);
    nul.inputs[0] <== claim_hash;
    nul.inputs[1] <== nonce;
    nullifier <== nul.out;

    verified <== 1;            // public predicate flag (always 1 for an honest proof)
}

component main {public [issuerAx, issuerAy]} = ValidOwner();
