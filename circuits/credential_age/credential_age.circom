pragma circom 2.0.0;

// ============================================================================
// Veritas — Flagship "ZK Credential Age Gate"
// ============================================================================
// Proves, WITHOUT revealing the holder's age or any document:
//   1. The holder possesses a credential genuinely signed by a known issuer
//      (EdDSA over BabyJubJub, Poseidon as the challenge hash). This binds
//      {age, holderSecret} to the issuer's authority.
//   2. The credential's private `age` is >= the public `threshold` (e.g. 18).
//      If not, the circuit has NO satisfying witness and no proof can exist.
//   3. A per-credential `nullifier` (= Poseidon(holderSecret)) is revealed so
//      the on-chain contract can detect double-use while the holder stays
//      pseudonymous and the age itself is never exposed.
//
// The issuer never learns the proof; the verifier (Soroban) never learns the
// age or the signature — only "this nullifier corresponds to an issuer-signed
// credential whose holder is `threshold` years or older".
//
// Primitives: Poseidon hash + EdDSA-BabyJubJub, all from iden3/circomlib.
// Proof system: Groth16 on BN254 (verified on-chain by a Soroban contract).
// ============================================================================

include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template CredentialAge() {
    // ---- private inputs (known to prover + issuer only) ----
    signal input age;            // holder's age (e.g. 25)
    signal input holderSecret;   // per-credential secret (nullifier seed)
    signal input sigR8x;         // EdDSA signature: R8.x
    signal input sigR8y;         // EdDSA signature: R8.y
    signal input sigS;           // EdDSA signature: S scalar

    // ---- public inputs ----
    signal input issuerAx;       // issuer BabyJubJub public key .x
    signal input issuerAy;       // issuer BabyJubJub public key .y
    signal input threshold;      // required minimum age (e.g. 18)

    // ---- public outputs ----
    signal output nullifier;     // Poseidon(holderSecret) — double-spend tag

    // 1. The exact message the issuer signed off-chain.
    //    signer signs  m = Poseidon(age, holderSecret)  as a single field element.
    component signedMsg = Poseidon(2);
    signedMsg.inputs[0] <== age;
    signedMsg.inputs[1] <== holderSecret;

    // 2. Verify the issuer's EdDSA-Poseidon signature over m.
    //    If the signature is invalid, this template forces a constraint failure
    //    and no proof can be produced.
    component eddsa = EdDSAPoseidonVerifier();
    eddsa.enabled <== 1;
    eddsa.Ax <== issuerAx;
    eddsa.Ay <== issuerAy;
    eddsa.R8x <== sigR8x;
    eddsa.R8y <== sigR8y;
    eddsa.S <== sigS;
    eddsa.M <== signedMsg.out;

    // 3. Range predicate: age >= threshold.  16-bit comparison is far more than
    //    enough for human ages.  `ge.out === 1` means any witness with
    //    age < threshold is impossible — i.e. the proof cannot exist.
    component ge = GreaterEqThan(16);
    ge.in[0] <== age;
    ge.in[1] <== threshold;
    ge.out === 1;

    // 4. Public nullifier: deterministic per credential, reveals nothing about
    //    age, lets the contract reject a replayed proof.
    component nf = Poseidon(1);
    nf.inputs[0] <== holderSecret;
    nullifier <== nf.out;
}

// nullifier is a public OUTPUT, so it is public automatically (not listed below).
component main {public [issuerAx, issuerAy, threshold]} = CredentialAge();
