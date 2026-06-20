//! Definitive correctness test: verify REAL snarkjs Groth16 proofs generated
//! from the Veritas circom circuits. If this passes, the on-chain pairing
//! math is correct (it's the same `groth16` module the Soroban contract uses).
//!
//! Run:  cargo test --test verify_real   (from soroban/verifier/)

use std::fs;

use ark_bn254::{Fq, Fq2, Fr, G1Affine, G2Affine};
use ark_ff::PrimeField;
use serde_json::Value;

use veritas_verifier::groth16::{verify_groth16, Proof, VerifyingKey};

const ZKEYS: &str = "../../../circuits/build/zkeys";

/// decimal string -> big-endian bytes (no leading zeros), then reduce mod the
/// field order. `from_be_bytes_mod_order` accepts any length.
fn dec(s: &str) -> Vec<u8> {
    let mut limbs: Vec<u32> = vec![0]; // base 2^32, little-endian
    for b in s.bytes() {
        let d = (b - b'0') as u64;
        let mut carry = d;
        for x in limbs.iter_mut() {
            let v = (*x as u64) * 10 + carry;
            *x = (v & 0xffff_ffff) as u32;
            carry = v >> 32;
        }
        while carry > 0 {
            limbs.push((carry & 0xffff_ffff) as u32);
            carry >>= 32;
        }
    }
    let mut bytes = Vec::with_capacity(limbs.len() * 4);
    for x in limbs.iter().rev() {
        bytes.extend_from_slice(&x.to_be_bytes());
    }
    while bytes.len() > 1 && bytes[0] == 0 {
        bytes.remove(0);
    }
    bytes
}

fn fq(s: &str) -> Fq {
    Fq::from_be_bytes_mod_order(&dec(s))
}
fn fr(s: &str) -> Fr {
    Fr::from_be_bytes_mod_order(&dec(s))
}

/// snarkjs G1 = ["x","y","1"];  G2 = [["x.c1","x.c0"],["y.c1","y.c0"],["1","0"]].
fn g1_of(v: &Value) -> G1Affine {
    G1Affine::new_unchecked(fq(v[0].as_str().unwrap()), fq(v[1].as_str().unwrap()))
}
fn g2_of(v: &Value) -> G2Affine {
    // snarkjs JSON Fq2 pair is [c0, c1] (c0 FIRST); Fq2 = c0 + c1·u.
    let xc0 = fq(v[0][0].as_str().unwrap());
    let xc1 = fq(v[0][1].as_str().unwrap());
    let yc0 = fq(v[1][0].as_str().unwrap());
    let yc1 = fq(v[1][1].as_str().unwrap());
    G2Affine::new_unchecked(Fq2::new(xc0, xc1), Fq2::new(yc0, yc1))
}

fn load(circuit: &str) -> (VerifyingKey, Vec<Fr>, Proof) {
    let vk_json: Value =
        serde_json::from_str(&fs::read_to_string(format!("{ZKEYS}/{circuit}_vkey.json")).unwrap())
            .unwrap();
    let vk = VerifyingKey {
        alpha_g1: g1_of(&vk_json["vk_alpha_1"]),
        beta_g2: g2_of(&vk_json["vk_beta_2"]),
        gamma_g2: g2_of(&vk_json["vk_gamma_2"]),
        delta_g2: g2_of(&vk_json["vk_delta_2"]),
        ic: vk_json["IC"].as_array().unwrap().iter().map(g1_of).collect(),
    };

    let public: Vec<Fr> = serde_json::from_str::<Value>(
        &fs::read_to_string(format!("{ZKEYS}/{circuit}_public.json")).unwrap(),
    )
    .unwrap()
    .as_array()
    .unwrap()
    .iter()
    .map(|v| fr(v.as_str().unwrap()))
    .collect();

    let proof_json: Value = serde_json::from_str(
        &fs::read_to_string(format!("{ZKEYS}/{circuit}_proof.json")).unwrap(),
    )
    .unwrap();
    let proof = Proof {
        a: g1_of(&proof_json["pi_a"]),
        b: g2_of(&proof_json["pi_b"]),
        c: g1_of(&proof_json["pi_c"]),
    };
    (vk, public, proof)
}

#[test]
fn verifies_all_real_proofs() {
    for circuit in ["AgeGte", "ValidOwner", "JurisdictionAllowed"] {
        let (vk, public, proof) = load(circuit);
        assert_eq!(vk.ic.len(), public.len() + 1, "{circuit}: IC/public mismatch");
        let ok = verify_groth16(&vk, &public, &proof);
        assert!(ok, "{circuit}: REAL proof failed to verify (math is wrong!)");
        println!("✓ {circuit}: real Groth16 proof verified on-chain core");
    }
}

#[test]
fn rejects_tampered_public_input() {
    // AgeGte: flip `threshold` (index 5) — a correct proof bound to threshold=18
    // must NOT verify against a tampered threshold (e.g. 21).
    let (vk, mut public, proof) = load("AgeGte");
    public[5] = fr("21"); // claim "age >= 21" using a proof built for 18
    assert!(!verify_groth16(&vk, &public, &proof), "tampered threshold accepted");
    println!("✓ AgeGte: tampered threshold correctly REJECTED");
}

#[test]
fn rejects_cross_circuit_proof() {
    // A ValidOwner proof must not verify under the AgeGte key (different vkey).
    let (vk_age, _, _) = load("AgeGte");
    let (_vk_owner, pub_owner, proof_owner) = load("ValidOwner");
    let ok = verify_groth16(&vk_age, &pub_owner, &proof_owner);
    assert!(!ok, "cross-circuit proof accepted");
    println!("✓ cross-circuit proof correctly REJECTED");
}
