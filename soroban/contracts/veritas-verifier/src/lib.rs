//! Veritas — on-chain Groth16 credential verifier for Soroban (Stellar).
//!
//! The crate root wires together three building blocks:
//!   * [`groth16`] — `#![no_std]` + `alloc` BN254 / Groth16 pairing core.
//!     The *same* code runs inside the WASM contract and in host unit tests
//!     (see `tests/verify_real.rs`, which verifies REAL snarkjs proofs).
//!   * [`spec`]    — public-signal layout for each Veritas circom circuit.
//!   * [`contract`] — the `VeritasVerifier` Soroban contract that exposes
//!     `verify` / `verify_for` / `verify_credential` / `claim_faucet` and the
//!     admin configurators (`set_verifying_key`, `set_default_circuit`,
//!     `set_issuer`, `set_allowed_root`).
//!
//! Byte encodings (big-endian, no length prefixes) are documented on the
//! [`contract`] module. Public surface used by the integration tests:
//! `veritas_verifier::contract::{VeritasVerifier, VeritasVerifierClient}`
//! and `veritas_verifier::groth16::{verify_groth16, Proof, VerifyingKey}`.

#![cfg_attr(target_family = "wasm", no_std)]

pub mod contract;
pub mod groth16;
pub mod spec;
