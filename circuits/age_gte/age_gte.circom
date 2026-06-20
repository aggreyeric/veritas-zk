pragma circom 2.1.6;

// ============================================================================
// Veritas — "AgeGte": private age predicate over a Poseidon commitment
// ============================================================================
// A lighter circuit than CredentialAge: there is NO signature here.  It proves
// "I know a private `age` and `salt` whose Poseidon commitment matches a public
// value, AND age >= threshold".  This is the pure "derived predicate over a
// private datum" primitive — useful as a building block and as a comparison
// point against the signed-credential flagship circuit.
//
// Demonstrates: Poseidon commitment + range comparison (circomlib GreaterEqThan)
// without any document disclosure.
// ============================================================================

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

template AgeGte() {
    // private
    signal input age;          // holder's real age
    signal input salt;         // blinding salt for the commitment

    // public
    signal input threshold;    // required minimum age (e.g. 18)
    signal output commitment;  // Poseidon(age, salt) — public, hides age
    signal output ageGte;      // 1 (circuit is unsatisfiable if age < threshold)

    // age >= threshold (16-bit range)
    component ge = GreaterEqThan(16);
    ge.in[0] <== age;
    ge.in[1] <== threshold;
    ge.out === 1;
    ageGte <== ge.out;

    // commitment reveals nothing about age individually
    component cmt = Poseidon(2);
    cmt.inputs[0] <== age;
    cmt.inputs[1] <== salt;
    commitment <== cmt.out;
}

component main {public [threshold]} = AgeGte();
