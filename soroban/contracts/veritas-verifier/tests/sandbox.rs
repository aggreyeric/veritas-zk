//! End-to-end Soroban test: deploys the verifier in the sandbox and verifies
//! REAL snarkjs proofs converted into the contract's byte format. This is the
//! "meaningful ZK integration with Stellar" proof — the on-chain contract
//! accepts real Groth16 proofs and returns the correct verdict.
//!
//! Run:  cargo test --test sandbox -- --nocapture

use std::fs;
use serde_json::Value;
use soroban_sdk::{Address, Bytes, BytesN, Env, testutils::Address as _};
use veritas_verifier::contract::{VeritasVerifier, VeritasVerifierClient};

const ZKEYS: &str = "../../../circuits/build/zkeys";

fn dec(s: &str) -> Vec<u8> {
    let mut limbs: Vec<u32> = vec![0];
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
    let mut bytes = Vec::new();
    for x in limbs.iter().rev() {
        bytes.extend_from_slice(&x.to_be_bytes());
    }
    while bytes.len() > 1 && bytes[0] == 0 {
        bytes.remove(0);
    }
    pad32(&bytes)
}
fn pad32(b: &[u8]) -> Vec<u8> {
    let mut out = vec![0u8; 32 - b.len()];
    out.extend_from_slice(b);
    out
}
fn dec32(s: &str) -> [u8; 32] {
    let v = dec(s);
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&v);
    arr
}

fn load_json(name: &str) -> Value {
    serde_json::from_str(&fs::read_to_string(format!("{ZKEYS}/{name}")).unwrap()).unwrap()
}

/// 256-B proof blob: A.x A.y | B.x.c0 B.x.c1 B.y.c0 B.y.c1 | C.x C.y
fn proof_blob(p: &Value) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend(dec(p["pi_a"][0].as_str().unwrap()));
    out.extend(dec(p["pi_a"][1].as_str().unwrap()));
    out.extend(dec(p["pi_b"][0][0].as_str().unwrap())); // B.x.c0
    out.extend(dec(p["pi_b"][0][1].as_str().unwrap())); // B.x.c1
    out.extend(dec(p["pi_b"][1][0].as_str().unwrap())); // B.y.c0
    out.extend(dec(p["pi_b"][1][1].as_str().unwrap())); // B.y.c1
    out.extend(dec(p["pi_c"][0].as_str().unwrap()));
    out.extend(dec(p["pi_c"][1].as_str().unwrap()));
    out
}

fn public_blob(p: &Value) -> Vec<u8> {
    p.as_array().unwrap().iter().fold(Vec::new(), |mut a, v| {
        a.extend(dec(v.as_str().unwrap()));
        a
    })
}

/// vk blob: alpha(2) beta(4) gamma(4) delta(4) nPublic(1) IC[(n+1)*2]
fn vk_blob(vk: &Value, public: &Value) -> Vec<u8> {
    let mut out = Vec::new();
    let g1 = |o: &mut Vec<u8>, v: &Value| {
        o.extend(dec(v[0].as_str().unwrap()));
        o.extend(dec(v[1].as_str().unwrap()));
    };
    let g2 = |o: &mut Vec<u8>, v: &Value| {
        // x = (c0,c1), y = (c0,c1)
        o.extend(dec(v[0][0].as_str().unwrap())); // x.c0
        o.extend(dec(v[0][1].as_str().unwrap())); // x.c1
        o.extend(dec(v[1][0].as_str().unwrap())); // y.c0
        o.extend(dec(v[1][1].as_str().unwrap())); // y.c1
    };
    g1(&mut out, &vk["vk_alpha_1"]);
    g2(&mut out, &vk["vk_beta_2"]);
    g2(&mut out, &vk["vk_gamma_2"]);
    g2(&mut out, &vk["vk_delta_2"]);
    let n = public.as_array().unwrap().len();
    out.push(n as u8);
    for pt in vk["IC"].as_array().unwrap() {
        g1(&mut out, pt);
    }
    out
}

fn deploy(env: &Env) -> VeritasVerifierClient {
    let admin = Address::generate(env);
    let id = env.register(VeritasVerifier, (&admin,));
    let client = VeritasVerifierClient::new(env, &id);
    env.mock_all_auths();
    client
}

#[test]
#[ignore] // requires circuits/build/zkeys/ — run with `cargo test -- --ignored`
fn age_gte_verifies_on_chain() {
    let env = Env::default();
    let client = deploy(&env);
    let vk = load_json("AgeGte_vkey.json");
    let public = load_json("AgeGte_public.json");
    let proof = load_json("AgeGte_proof.json");

    client.set_verifying_key(&0u32, &Bytes::from_slice(&env, &vk_blob(&vk, &public)));
    client.set_default_circuit(&0u32);

    let pb = proof_blob(&proof);
    let pub_b = public_blob(&public);
    assert_eq!(pb.len(), 256);
    assert_eq!(pub_b.len(), 6 * 32);

    // pure Groth16 verify
    assert!(client.verify_for(&0u32, &Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &pub_b)));
    assert!(client.verify(&Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &pub_b)));

    // tampered threshold (public[5]) must fail
    let mut tampered = pub_b.clone();
    tampered[5 * 32..].copy_from_slice(&dec("21"));
    assert!(!client.verify(&Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &tampered)));

    // gated action
    let recipient = Address::generate(&env);
    assert!(client.claim_faucet(&recipient, &0u32, &Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &pub_b)));
    println!("✓ AgeGte verified on-chain + faucet unlocked");
}

#[test]
#[ignore] // requires circuits/build/zkeys/ — run with `cargo test -- --ignored`
fn valid_owner_double_spend_protection() {
    let env = Env::default();
    let client = deploy(&env);
    let vk = load_json("ValidOwner_vkey.json");
    let public = load_json("ValidOwner_public.json");
    let proof = load_json("ValidOwner_proof.json");

    client.set_verifying_key(&1u32, &Bytes::from_slice(&env, &vk_blob(&vk, &public)));
    // issuer pubkey lives at public[2],[3]
    let ax = BytesN::<32>::from_array(&env, &dec32(public[2].as_str().unwrap()));
    let ay = BytesN::<32>::from_array(&env, &dec32(public[3].as_str().unwrap()));
    client.set_issuer(&ax, &ay);

    let pb = proof_blob(&proof);
    let pub_b = public_blob(&public);

    assert!(client.verify_credential(&1u32, &Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &pub_b)));
    // replay the SAME credential => nullifier already recorded => rejected
    assert!(!client.verify_credential(&1u32, &Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &pub_b)));
    println!("✓ ValidOwner verified on-chain + double-spend blocked");
}

#[test]
#[ignore] // requires circuits/build/zkeys/ — run with `cargo test -- --ignored`
fn jurisdiction_allowed_verifies_on_chain() {
    let env = Env::default();
    let client = deploy(&env);
    let vk = load_json("JurisdictionAllowed_vkey.json");
    let public = load_json("JurisdictionAllowed_public.json");
    let proof = load_json("JurisdictionAllowed_proof.json");

    client.set_verifying_key(&2u32, &Bytes::from_slice(&env, &vk_blob(&vk, &public)));
    // merkleRoot at public[2]; must equal the posted on-chain root
    let root = BytesN::<32>::from_array(&env, &dec32(public[2].as_str().unwrap()));
    client.set_allowed_root(&root);

    let pb = proof_blob(&proof);
    let pub_b = public_blob(&public);
    assert!(client.verify_credential(&2u32, &Bytes::from_slice(&env, &pb), &Bytes::from_slice(&env, &pub_b)));
    println!("✓ JurisdictionAllowed verified on-chain against posted root");
}
