pragma circom 2.1.6;

// ============================================================================
// Veritas — "JurisdictionAllowed": private membership in a public allow-set
// ============================================================================
// Proves, WITHOUT revealing the holder's country:
//   1. The holder possesses a credential genuinely signed by a known issuer
//      (EdDSA-Poseidon over BabyJubJub). The signed message is
//      m = Poseidon(country, holderSecret), binding the country to the issuer's
//      authority and to the holder's secret.
//   2. The signed `country` is a MEMBER of a public Poseidon Merkle tree whose
//      root is `allowedRoot` (the on-chain allow / non-sanctioned set). A valid
//      Merkle path proves membership; the specific country stays hidden.
//   3. A per-credential nullifier (= Poseidon(holderSecret)) is revealed so the
//      contract can detect double-use while the holder stays pseudonymous.
//
// Net statement to the Soroban verifier:
//   "I hold an issuer-signed credential whose country is in the on-chain allowed
//    set" — and NOTHING about which country, the holder's identity, or the doc.
//
// Privacy note (documented honestly in README): because the leaf is the country
// value itself, an observer who knows the public allowed-set learns only that
// the holder's country is one of the N members (1/N ambiguity). For production
// you would hash each leaf with a per-tree domain separator; we keep leaves raw
// for demo simplicity and smaller constraints.
//
// Primitives: Poseidon hash + EdDSA-BabyJubJub + Poseidon Merkle tree
// (circuits/lib/merkle_poseidon.circom), all from iden3/circomlib.
// Proof system: Groth16 on BN254 (verified on-chain by a Soroban contract).
// ============================================================================

include "../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../lib/merkle_poseidon.circom";

template JurisdictionAllowed(depth) {
    // ---- private inputs (prover + issuer only) ----
    signal input country;              // holder's country code (field element, e.g. ISO numeric)
    signal input holderSecret;         // per-credential secret (nullifier seed)
    signal input sigR8x;               // EdDSA signature: R8.x
    signal input sigR8y;               // EdDSA signature: R8.y
    signal input sigS;                 // EdDSA signature: S scalar
    signal input pathElements[depth];  // Merkle sibling hashes, bottom -> top
    signal input pathIndices[depth];   // Merkle direction bits (0/1), bottom -> top

    // ---- public inputs ----
    signal input issuerAx;             // issuer BabyJubJub public key .x
    signal input issuerAy;             // issuer BabyJubJub public key .y
    signal input allowedRoot;          // public Merkle root of the allowed-set tree

    // ---- public output ----
    signal output nullifier;           // Poseidon(holderSecret) — double-spend tag

    // 1. The exact message the issuer signed off-chain.
    //    m = Poseidon(country, holderSecret)
    component signedMsg = Poseidon(2);
    signedMsg.inputs[0] <== country;
    signedMsg.inputs[1] <== holderSecret;

    // 2. Verify the issuer's EdDSA-Poseidon signature over m.
    component eddsa = EdDSAPoseidonVerifier();
    eddsa.enabled <== 1;
    eddsa.Ax <== issuerAx;
    eddsa.Ay <== issuerAy;
    eddsa.R8x <== sigR8x;
    eddsa.R8y <== sigR8y;
    eddsa.S <== sigS;
    eddsa.M <== signedMsg.out;

    // 3. Merkle membership: the SIGNED country is in the public allowed-set tree.
    //    root === allowedRoot enforces the proof is against the on-chain set.
    component mt = MerklePoseidonVerifier(depth);
    mt.leaf <== country;
    for (var i = 0; i < depth; i++) {
        mt.pathElements[i] <== pathElements[i];
        mt.pathIndices[i] <== pathIndices[i];
    }
    mt.root === allowedRoot;

    // 4. Public nullifier — deterministic per credential, reveals nothing about
    //    country, lets the contract reject a replayed proof.
    component nf = Poseidon(1);
    nf.inputs[0] <== holderSecret;
    nullifier <== nf.out;
}

// Tree depth 8 => up to 256 allowed countries (plenty for an ISO-3166 set).
// nullifier is a public OUTPUT; issuer key + allowedRoot are the public inputs.
component main {public [issuerAx, issuerAy, allowedRoot]} = JurisdictionAllowed(8);
