pragma circom 2.1.6;

// ============================================================================
// Veritas — "ValidOwner": credential validity + ownership, no derived predicate
// ============================================================================
// Proves, WITHOUT revealing any attribute:
//   1. The holder possesses a credential genuinely signed by a known issuer
//      (EdDSA over BabyJubJub, Poseidon challenge hash). The signed message is
//      m = Poseidon(claimField, holderSecret), binding the attribute to the
//      issuer's authority and to the holder's secret.
//   2. A per-credential nullifier (= Poseidon(holderSecret)) is revealed so the
//      on-chain Soroban contract can reject replays / double-use, while the
//      holder stays pseudonymous and `claimField` is never exposed.
//
// This is the base "I possess a valid, issuer-signed credential that belongs to
// me" primitive — used when you need NO derived predicate (e.g. "registered
// member" gating, syndicate membership, allow-list membership where the mere
// existence of a valid signature is the gate).
//
// Primitives: Poseidon hash + EdDSA-BabyJubJub from iden3/circomlib.
// Proof system: Groth16 on BN254 (verified on-chain by a Soroban contract).
// ============================================================================

include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template ValidOwner() {
    // ---- private inputs (prover + issuer only) ----
    signal input claimField;      // the signed attribute (age, country, role, ...) — kept private
    signal input holderSecret;    // per-credential secret (nullifier seed)
    signal input sigR8x;          // EdDSA signature: R8.x
    signal input sigR8y;          // EdDSA signature: R8.y
    signal input sigS;            // EdDSA signature: S scalar

    // ---- public inputs ----
    signal input issuerAx;        // issuer BabyJubJub public key .x
    signal input issuerAy;        // issuer BabyJubJub public key .y

    // ---- public output ----
    signal output nullifier;      // Poseidon(holderSecret) — double-spend tag

    // 1. The exact message the issuer signed off-chain.
    //    m = Poseidon(claimField, holderSecret)
    component signedMsg = Poseidon(2);
    signedMsg.inputs[0] <== claimField;
    signedMsg.inputs[1] <== holderSecret;

    // 2. Verify the issuer's EdDSA-Poseidon signature over m.
    //    An invalid signature forces a constraint failure -> no proof can exist.
    component eddsa = EdDSAPoseidonVerifier();
    eddsa.enabled <== 1;
    eddsa.Ax <== issuerAx;
    eddsa.Ay <== issuerAy;
    eddsa.R8x <== sigR8x;
    eddsa.R8y <== sigR8y;
    eddsa.S <== sigS;
    eddsa.M <== signedMsg.out;

    // 3. Public nullifier — deterministic per credential, reveals nothing about
    //    claimField, lets the contract reject a replayed proof.
    component nf = Poseidon(1);
    nf.inputs[0] <== holderSecret;
    nullifier <== nf.out;
}

// nullifier is a public OUTPUT (public by default); issuer key is the public input.
component main {public [issuerAx, issuerAy]} = ValidOwner();
