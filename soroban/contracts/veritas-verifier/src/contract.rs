//! Veritas Soroban verifier contract.
//!
//! Stores one Groth16 verifying key per circuit plus a trusted issuer pubkey,
//! an allow-set Merkle root, and a nullifier set (double-spend protection).
//! Exposes:
//!   * `verify(proof_bytes, public_inputs_bytes) -> bool` — pure Groth16 check
//!     against the contract's *default* circuit (see `set_default_circuit`).
//!   * `verify_for(circuit, proof_bytes, public_inputs_bytes) -> bool` — same,
//!     for an explicit predicate.
//!   * `verify_credential(...)` — verify_for + issuer/nullifier/flag semantics.
//!   * `claim_faucet(...)` — gated action that unlocks only on a valid proof.
//!
//! # Byte encodings (big-endian, no length prefixes)
//! * `proof_bytes` (256 B): `A.x|A.y | B.x.c0|B.x.c1|B.y.c0|B.y.c1 | C.x|C.y`
//!   (8 × 32-byte field elements; G2 stores c0 BEFORE c1, matching arkworks).
//! * `public_inputs_bytes`: `nPublic × 32 B` (Fr scalars, snarkjs `public.json`
//!   order: outputs then inputs, NO leading 1).
//! * `vk_bytes`: `α.x|α.y | β.{c0,c1}×2 | γ... | δ... | nPublic(1 B) |
//!   (nPublic+1) × (IC.x|IC.y)`.

extern crate alloc;

use alloc::vec::Vec;

use ark_bn254::{Fq, Fq2, Fr, G1Affine, G2Affine};
use ark_ff::PrimeField;
use soroban_sdk::{
    contract, contractimpl, contracttype, symbol_short, Address, Bytes, BytesN, Env, Symbol,
};

use crate::groth16::{verify_groth16, Proof, VerifyingKey};
use crate::spec::CircuitId;

// 9-char (short) symbols avoid the 32-byte long-symbol cost on Soroban.
const S_ADMIN: Symbol = symbol_short!("admin");
const S_DEFAULT: Symbol = symbol_short!("default");
const S_ISS_AX: Symbol = symbol_short!("issax");
const S_ISS_AY: Symbol = symbol_short!("issay");
const S_ROOT: Symbol = symbol_short!("root");
const S_CLAIMED: Symbol = symbol_short!("claimed");

#[contracttype]
pub enum DataKey {
    VerifyingKey(u32),
    /// Per-credential nullifier — presence == already spent.
    Nullifier(BytesN<32>),
}

#[contract]
pub struct VeritasVerifier;

#[contractimpl]
impl VeritasVerifier {
    /// One-time setup. Stores the deployer as admin.
    pub fn __constructor(env: Env, admin: Address) {
        env.storage().persistent().set(&S_ADMIN, &admin);
    }

    pub fn admin(env: Env) -> Address {
        env.storage().persistent().get(&S_ADMIN).unwrap()
    }

    fn require_admin(env: &Env) {
        let admin: Address = env.storage().persistent().get(&S_ADMIN).unwrap();
        admin.require_auth();
    }

    const fn cid(u: u32) -> CircuitId {
        match u {
            0 => CircuitId::AgeGte,
            1 => CircuitId::ValidOwner,
            2 => CircuitId::JurisdictionAllowed,
            3 => CircuitId::CredentialAge,
            _ => CircuitId::AgeGte, // callers guard with check_circuit_id
        }
    }

    fn check_circuit_id(u: u32) -> bool {
        u <= 3
    }

    // ---- admin configuration ------------------------------------------------

    /// Install (or replace) the Groth16 verifying key for a circuit.
    pub fn set_verifying_key(env: Env, circuit: u32, vk: Bytes) {
        Self::require_admin(&env);
        env.storage()
            .persistent()
            .set(&DataKey::VerifyingKey(circuit), &vk);
    }

    /// Which circuit `verify()` (no circuit arg) targets.
    pub fn set_default_circuit(env: Env, circuit: u32) {
        Self::require_admin(&env);
        env.storage().persistent().set(&S_DEFAULT, &circuit);
    }

    /// Register the single trusted issuer BabyJub pubkey (ax, ay) for the demo.
    pub fn set_issuer(env: Env, ax: BytesN<32>, ay: BytesN<32>) {
        Self::require_admin(&env);
        env.storage().persistent().set(&S_ISS_AX, &ax);
        env.storage().persistent().set(&S_ISS_AY, &ay);
    }

    /// Post the allow-set Merkle root for JurisdictionAllowed.
    pub fn set_allowed_root(env: Env, root: BytesN<32>) {
        Self::require_admin(&env);
        env.storage().persistent().set(&S_ROOT, &root);
    }

    // ---- byte parsing -------------------------------------------------------

    fn to_vec(env: &Env, b: &Bytes) -> Vec<u8> {
        let mut out = Vec::new();
        let mut it = b.iter();
        while let Some(byte) = it.next() {
            out.push(byte);
        }
        // `env` is referenced implicitly via `b`'s lifetime; keep the param for API symmetry.
        let _ = env;
        out
    }

    fn read_fq(b: &[u8], o: &mut usize) -> Fq {
        let chunk = &b[*o..*o + 32];
        *o += 32;
        Fq::from_be_bytes_mod_order(chunk)
    }

    fn read_fr(b: &[u8], o: &mut usize) -> Fr {
        let chunk = &b[*o..*o + 32];
        *o += 32;
        Fr::from_be_bytes_mod_order(chunk)
    }

    /// Parse a 256-B proof blob into a Groth16 `Proof`.
    fn parse_proof(b: &[u8]) -> Proof {
        let mut o = 0usize;
        let ax = Self::read_fq(b, &mut o);
        let ay = Self::read_fq(b, &mut o);
        let bxc0 = Self::read_fq(b, &mut o);
        let bxc1 = Self::read_fq(b, &mut o);
        let byc0 = Self::read_fq(b, &mut o);
        let byc1 = Self::read_fq(b, &mut o);
        let cx = Self::read_fq(b, &mut o);
        let cy = Self::read_fq(b, &mut o);
        Proof {
            a: G1Affine::new_unchecked(ax, ay),
            b: G2Affine::new_unchecked(Fq2::new(bxc0, bxc1), Fq2::new(byc0, byc1)),
            c: G1Affine::new_unchecked(cx, cy),
        }
    }

    /// Parse a stored `vk_bytes` blob into a `VerifyingKey`.
    fn parse_vk(b: &[u8]) -> VerifyingKey {
        let mut o = 0usize;
        let alpha_g1 = G1Affine::new_unchecked(Self::read_fq(b, &mut o), Self::read_fq(b, &mut o));
        let take_g2 = |b: &[u8], o: &mut usize| -> G2Affine {
            let c0a = Self::read_fq(b, o);
            let c1a = Self::read_fq(b, o);
            let c0b = Self::read_fq(b, o);
            let c1b = Self::read_fq(b, o);
            G2Affine::new_unchecked(Fq2::new(c0a, c1a), Fq2::new(c0b, c1b))
        };
        let beta_g2 = take_g2(b, &mut o);
        let gamma_g2 = take_g2(b, &mut o);
        let delta_g2 = take_g2(b, &mut o);
        let n = b[o] as usize;
        o += 1;
        let mut ic = Vec::new();
        let mut i = 0;
        while i <= n {
            ic.push(G1Affine::new_unchecked(
                Self::read_fq(b, &mut o),
                Self::read_fq(b, &mut o),
            ));
            i += 1;
        }
        VerifyingKey {
            alpha_g1,
            beta_g2,
            gamma_g2,
            delta_g2,
            ic,
        }
    }

    fn fr_to_bytesn(env: &Env, f: Fr) -> BytesN<32> {
        // canonical big-endian 32-byte integer of the field element
        let limbs = f.into_bigint().0; // [u64; 4], little-endian
        let mut arr = [0u8; 32];
        let mut i = 0;
        while i < 4 {
            let bytes = limbs[3 - i].to_be_bytes();
            arr[i * 8] = bytes[0];
            arr[i * 8 + 1] = bytes[1];
            arr[i * 8 + 2] = bytes[2];
            arr[i * 8 + 3] = bytes[3];
            arr[i * 8 + 4] = bytes[4];
            arr[i * 8 + 5] = bytes[5];
            arr[i * 8 + 6] = bytes[6];
            arr[i * 8 + 7] = bytes[7];
            i += 1;
        }
        BytesN::<32>::from_array(env, &arr)
    }

    // ---- verification -------------------------------------------------------

    fn stored_vk(env: &Env, circuit: u32) -> VerifyingKey {
        let raw: Bytes = env
            .storage()
            .persistent()
            .get(&DataKey::VerifyingKey(circuit))
            .unwrap_or_else(|| panic!("vkey for circuit {circuit} not installed"));
        Self::parse_vk(&Self::to_vec(env, &raw))
    }

    /// Verify a proof for an explicit circuit. Pure Groth16 pairing check.
    pub fn verify_for(env: Env, circuit: u32, proof: Bytes, public: Bytes) -> bool {
        if !Self::check_circuit_id(circuit) {
            return false;
        }
        let proof_blob = Self::to_vec(&env, &proof);
        let pub_blob = Self::to_vec(&env, &public);
        if proof_blob.len() != 256 || pub_blob.len() % 32 != 0 {
            return false;
        }
        let vk = Self::stored_vk(&env, circuit);
        let proof = Self::parse_proof(&proof_blob);
        let n = pub_blob.len() / 32;
        let mut public_sig = Vec::new();
        let mut o = 0usize;
        let mut i = 0;
        while i < n {
            public_sig.push(Self::read_fr(&pub_blob, &mut o));
            i += 1;
        }
        verify_groth16(&vk, &public_sig, &proof)
    }

    /// The signature called out by the brief: verify against the default circuit.
    pub fn verify(env: Env, proof: Bytes, public: Bytes) -> bool {
        let circuit: u32 = env
            .storage()
            .persistent()
            .get(&S_DEFAULT)
            .unwrap_or_else(|| panic!("no default circuit configured"));
        Self::verify_for(env, circuit, proof, public)
    }

    /// Verify + enforce circuit semantics:
    ///   * predicate flag (ageGte/verified/allowed) must equal 1,
    ///   * issuer pubkey (where present) must match the trusted issuer,
    ///   * Merkle root (JurisdictionAllowed) must match the posted root,
    ///   * nullifier (where present) is recorded for double-spend protection.
    /// Returns false (never panics) on any semantic failure.
    pub fn verify_credential(env: Env, circuit: u32, proof: Bytes, public: Bytes) -> bool {
        if !Self::check_circuit_id(circuit) {
            return false;
        }
        let cid = Self::cid(circuit);
        let pub_blob = Self::to_vec(&env, &public);
        if pub_blob.len() != cid.n_public() * 32 {
            return false;
        }
        // cheap copies so we can move proof/public into verify_for
        if !Self::verify_for(env.clone(), circuit, proof, public) {
            return false;
        }
        let mut o = 0usize;
        let mut pub_fr = Vec::new();
        let mut i = 0;
        while i < cid.n_public() {
            pub_fr.push(Self::read_fr(&pub_blob, &mut o));
            i += 1;
        }

        // predicate flag must be 1 (where the circuit emits one)
        if cid.flag_index() != usize::MAX {
            if pub_fr[cid.flag_index()] != Fr::from(1u32) {
                return false;
            }
        }

        // issuer must match the trusted issuer
        if let Some((ix, iy)) = cid.issuer_index() {
            let ax: BytesN<32> = env
                .storage()
                .persistent()
                .get(&S_ISS_AX)
                .unwrap_or_else(|| panic!("no issuer set"));
            let ay: BytesN<32> = env
                .storage()
                .persistent()
                .get(&S_ISS_AY)
                .unwrap_or_else(|| panic!("no issuer set"));
            if Self::fr_to_bytesn(&env, pub_fr[ix]) != ax
                || Self::fr_to_bytesn(&env, pub_fr[iy]) != ay
            {
                return false;
            }
        }

        // allow-set root must match the posted root
        if let Some(ri) = cid.root_index() {
            let root: BytesN<32> = env
                .storage()
                .persistent()
                .get(&S_ROOT)
                .unwrap_or_else(|| panic!("no allowed root set"));
            if Self::fr_to_bytesn(&env, pub_fr[ri]) != root {
                return false;
            }
        }

        // record nullifier for double-spend protection
        if let Some(ni) = cid.nullifier_index() {
            let nullifier = Self::fr_to_bytesn(&env, pub_fr[ni]);
            if env
                .storage()
                .persistent()
                .has(&DataKey::Nullifier(nullifier.clone()))
            {
                return false; // already used
            }
            env.storage()
                .persistent()
                .set(&DataKey::Nullifier(nullifier), &true);
        }
        true
    }

    // ---- gated demo action --------------------------------------------------

    /// Age-gated faucet claim. Unlocks only if the caller proves `age >= 18`
    /// (AgeGte or CredentialAge) with a fresh proof. Emits an event on success.
    pub fn claim_faucet(
        env: Env,
        recipient: Address,
        circuit: u32,
        proof: Bytes,
        public: Bytes,
    ) -> bool {
        recipient.require_auth();
        let ok = match Self::cid(circuit) {
            CircuitId::AgeGte | CircuitId::CredentialAge => {
                Self::verify_credential(env.clone(), circuit, proof, public)
            }
            _ => false,
        };
        if ok {
            env.storage().persistent().set(&S_CLAIMED, &recipient);
            env.events().publish((symbol_short!("faucet"),), recipient);
        }
        ok
    }

    /// Did anyone successfully claim? (demo introspection)
    pub fn last_claimant(env: Env) -> Option<Address> {
        env.storage().persistent().get(&S_CLAIMED)
    }
}
