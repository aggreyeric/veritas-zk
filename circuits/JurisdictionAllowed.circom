pragma circom 2.1.6;

// ============================================================================
// Veritas — "JurisdictionAllowed": private membership in a public allow-set
// ============================================================================
// MVP primitive #2 from the build brief. Proves, WITHOUT revealing the country,
// that the prover's `country_hash` is a LEAF of a public Poseidon Merkle tree
// whose root `merkleRoot` is posted on-chain (the on-chain allow / non-sanctioned
// set).
//
// `country_hash` is computed off-chain as Poseidon(country_code) by the issuer;
// the raw country never enters the circuit. The prover supplies `country_hash`
// and a Merkle proof (sibling hashes + direction bits); the circuit recomputes
// the root with Poseidon and constrains it to equal the public `merkleRoot`.
//
// Index convention (matches scripts/zk_helpers.js):
//   pathIndices[i] = 0 => at level i the CURRENT hash is the LEFT child,
//                        pathElements[i] is the RIGHT sibling.
//   pathIndices[i] = 1 => CURRENT hash is the RIGHT child,
//                        pathElements[i] is the LEFT sibling.
// Each direction bit is constrained to {0,1}.
//
// Primitives: Poseidon binary Merkle tree (lib/merkle_poseidon.circom).
// Proof system: Groth16 on BN254.
// ============================================================================

include "lib/merkle_poseidon.circom";

template JurisdictionAllowed(depth) {
    // ---- private inputs ----
    signal input country_hash;           // Poseidon(country) — the leaf, kept secret
    signal input pathElements[depth];    // sibling hashes, bottom -> top
    signal input pathIndices[depth];     // 0/1 direction bits, bottom -> top

    // ---- public input ----
    signal input merkleRoot;             // on-chain allow-set root (verifier-controlled)

    // ---- public outputs ----
    signal output computedRoot;          // Poseidon-recomputed root (== merkleRoot)
    signal output allowed;               // 1 for any valid proof (unsatisfiable otherwise)

    component tree = MerklePoseidonVerifier(depth);
    tree.leaf <== country_hash;
    for (var i = 0; i < depth; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }

    computedRoot <== tree.root;
    computedRoot === merkleRoot;         // membership constraint: leaf is in the set
    allowed <== 1;                       // public predicate flag (always 1 for an honest proof)
}

// depth 16 -> up to 2^16 = 65,536 members; comfortably within ptau_16.
component main {public [merkleRoot]} = JurisdictionAllowed(16);
