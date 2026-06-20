pragma circom 2.1.6;

// ============================================================================
// Veritas — "trivial" pipeline-proving circuit (retained from the Day-1 spike)
// ============================================================================
// Intentionally minimal: prove knowledge of x such that x*x == y (public).
// Value: it is the smallest possible end-to-end validation of the WHOLE pipeline
// (circom compile -> R1CS -> powers-of-tau -> Groth16 trusted setup -> snarkjs
// proof -> on-chain Soroban verify).  Kept as a regression/sanity test.
// ============================================================================

template PreimageKnowledge() {
    signal input x;
    signal output y;

    y <== x * x;
}

component main = PreimageKnowledge();
