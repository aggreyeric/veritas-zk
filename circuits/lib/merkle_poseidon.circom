pragma circom 2.1.6;

// ============================================================================
// Veritas — Reusable Poseidon binary Merkle tree (membership verifier)
// ============================================================================
// Standard binary Merkle tree where every internal node is
//   H = Poseidon(left, right).
// Used by JurisdictionAllowed to prove that a private `country` value is a
// member of the public `allowedRoot` commitment (the on-chain allowed /
// sanctions set) WITHOUT revealing which member.
//
// Index convention (matches the JS helper in scripts/merkle_tree.js):
//   pathIndices[i] = 0  =>  at level i the CURRENT hash is the LEFT child,
//                            `pathElements[i]` is the RIGHT sibling.
//   pathIndices[i] = 1  =>  CURRENT hash is the RIGHT child,
//                            `pathElements[i]` is the LEFT sibling.
// So:  left  = (idx==0) ? current : sibling
//      right = (idx==0) ? sibling  : current
// and the next hash is Poseidon(left, right).
//
// `pathIndices` is constrained to {0,1} so a malicious prover cannot pick a
// non-binary value to traverse into a fake branch.
// ============================================================================

include "../node_modules/circomlib/circuits/poseidon.circom";

template MerklePoseidonVerifier(depth) {
    signal input leaf;                  // the member being proven (at tree-leaf level)
    signal input pathElements[depth];   // sibling hashes, bottom -> top
    signal input pathIndices[depth];    // 0/1 direction bits, bottom -> top
    signal output root;

    signal hash[depth + 1];
    signal left[depth];
    signal right[depth];

    component hashers[depth];

    hash[0] <== leaf;

    for (var i = 0; i < depth; i++) {
        // force the direction bit to be binary
        pathIndices[i] * (pathIndices[i] - 1) === 0;

        // conditional swap via the canonical DualMux form (Tornado-style).
        // pathIndices[i] = 0 => current hash is LEFT, sibling is RIGHT
        // pathIndices[i] = 1 => current hash is RIGHT, sibling is LEFT
        left[i]  <== (pathElements[i] - hash[i]) * pathIndices[i] + hash[i];
        right[i] <== (hash[i] - pathElements[i]) * pathIndices[i] + pathElements[i];

        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== left[i];
        hashers[i].inputs[1] <== right[i];

        hash[i + 1] <== hashers[i].out;
    }

    root <== hash[depth];
}
