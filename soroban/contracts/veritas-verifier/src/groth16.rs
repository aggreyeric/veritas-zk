//! Veritas — Groth16 / BN254 verification core.
//!
//! `#![no_std]` + `alloc` only, so the *same* code runs in a Soroban WASM
//! contract and in host unit-tests. Correctness is proven by `tests/` which
//! verify REAL snarkjs proofs generated from the Veritas circom circuits.
//!
//! Verification equation (snarkjs / Solidity 4-pairing form):
//!
//! ```text
//!   e(-A, B) · e(ic, γ₂) · e(C, δ₂) · e(α₁, β₂) == 1
//!   where ic = IC[0] + Σ public[i] · IC[i+1]
//! ```
//!
//! `public` is the snarkjs `public.json` (public outputs followed by public
//! inputs, NO leading 1). IC[0] is the constant term already stored in the vkey.

extern crate alloc;

use alloc::vec::Vec;

use ark_bn254::{Bn254, Fq, Fq2, Fr, G1Affine, G2Affine, G1Projective};
use ark_ec::{pairing::Pairing, AffineRepr, CurveGroup};
use ark_ff::{One, PrimeField};
use core::ops::Neg;

/// Scalar field element (order of G1/G2 on BN254).
pub type Scalar = Fr;

#[derive(Debug, Clone)]
pub struct VerifyingKey {
    pub alpha_g1: G1Affine,
    pub beta_g2: G2Affine,
    pub gamma_g2: G2Affine,
    pub delta_g2: G2Affine,
    /// `nPublic + 1` points. `ic[0]` is the constant term.
    pub ic: Vec<G1Affine>,
}

#[derive(Debug, Clone)]
pub struct Proof {
    pub a: G1Affine,
    pub b: G2Affine,
    pub c: G1Affine,
}

/// Build a G1 affine point from raw coordinates (unchecked).
pub fn g1(x: Fq, y: Fq) -> G1Affine {
    G1Affine::new_unchecked(x, y)
}

/// Build a G2 affine point from raw Fq2 coordinates (unchecked).
pub fn g2(x: Fq2, y: Fq2) -> G2Affine {
    G2Affine::new_unchecked(x, y)
}

/// Reject structurally-invalid / non-curve proof or key points.
pub fn points_valid(vk: &VerifyingKey, proof: &Proof) -> bool {
    let g1_ok = |p: &G1Affine| p.is_on_curve() && p.is_in_correct_subgroup_assuming_on_curve();
    let g2_ok = |p: &G2Affine| p.is_on_curve() && p.is_in_correct_subgroup_assuming_on_curve();
    if !(g1_ok(&vk.alpha_g1)
        && g2_ok(&vk.beta_g2)
        && g2_ok(&vk.gamma_g2)
        && g2_ok(&vk.delta_g2)
        && g1_ok(&proof.a)
        && g2_ok(&proof.b)
        && g1_ok(&proof.c))
    {
        return false;
    }
    let mut i = 0;
    while i < vk.ic.len() {
        if !g1_ok(&vk.ic[i]) {
            return false;
        }
        i += 1;
    }
    true
}

/// Core Groth16 verification. Returns `false` on any length mismatch.
pub fn verify_groth16(vk: &VerifyingKey, public: &[Scalar], proof: &Proof) -> bool {
    // IC has nPublic+1 entries: index 0 is the constant, 1..=nPublic for inputs.
    if public.len() + 1 != vk.ic.len() {
        return false;
    }
    if !points_valid(vk, proof) {
        return false;
    }

    // ic = IC[0] + Σ public[i] · IC[i+1]   (accumulated in projective coords)
    let mut acc = G1Projective::from(vk.ic[0]);
    let n = public.len();
    let mut i = 0;
    while i < n {
        acc += vk.ic[i + 1].mul_bigint(public[i].into_bigint());
        i += 1;
    }
    let ic = acc.into_affine();

    // e(-A, B) · e(ic, γ₂) · e(C, δ₂) · e(α₁, β₂) == 1
    let neg_a = proof.a.neg();
    let g1s = [neg_a, ic, proof.c, vk.alpha_g1];
    let g2s = [proof.b, vk.gamma_g2, vk.delta_g2, vk.beta_g2];
    Bn254::multi_pairing(g1s.iter(), g2s.iter()).0.is_one()
}
