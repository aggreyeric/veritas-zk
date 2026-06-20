//! Circuit specifications — the public-signal layout for each Veritas circuit.
//!
//! snarkjs emits `public.json` = `[public_outputs..., public_inputs...]` with NO
//! leading `1`. These specs tell the on-chain verifier *which* signals carry an
//! issuer pubkey, a nullifier, a threshold, or a Merkle root, and where the
//! boolean predicate flag lives (always `1` for an honest proof — assertable
//! on-chain as a cheap sanity check before the expensive pairing).

/// The four Veritas predicates. Kept compact so it survives a Soroban Symbol.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CircuitId {
    /// `age >= threshold`, derived from a private DOB. No issuer signature here.
    AgeGte,
    /// Credential valid + owned; emits a per-use nullifier (double-spend key).
    ValidOwner,
    /// Country/jurisdiction ∈ an allow-set (Poseidon Merkle root).
    JurisdictionAllowed,
    /// Flagship: issuer-signed credential whose private `age >= threshold`,
    /// emits a nullifier. Combines ValidOwner + AgeGte into one proof.
    CredentialAge,
}

impl CircuitId {
    /// Number of public signals expected for this circuit's `public.json`.
    pub const fn n_public(self) -> usize {
        match self {
            CircuitId::AgeGte => 6,
            CircuitId::ValidOwner => 4,
            CircuitId::JurisdictionAllowed => 3,
            CircuitId::CredentialAge => 4,
        }
    }

    /// Index of the boolean predicate flag inside `public` (must equal 1).
    pub const fn flag_index(self) -> usize {
        match self {
            CircuitId::AgeGte => 1,            // ageGte
            CircuitId::ValidOwner => 1,        // verified
            CircuitId::JurisdictionAllowed => 1, // allowed
            // CredentialAge has no explicit flag (no proof => unsatisfiable).
            CircuitId::CredentialAge => usize::MAX,
        }
    }

    /// `(ax_index, ay_index)` of the issuer BabyJub pubkey in `public`, if any.
    pub const fn issuer_index(self) -> Option<(usize, usize)> {
        match self {
            CircuitId::ValidOwner => Some((2, 3)),
            CircuitId::CredentialAge => Some((1, 2)),
            _ => None,
        }
    }

    /// Index of the revealed nullifier in `public`, if the circuit emits one.
    pub const fn nullifier_index(self) -> Option<usize> {
        match self {
            CircuitId::ValidOwner => Some(0),
            CircuitId::CredentialAge => Some(0),
            _ => None,
        }
    }

    /// Index of the on-chain Merkle allow-set root in `public`, if any.
    pub const fn root_index(self) -> Option<usize> {
        match self {
            CircuitId::JurisdictionAllowed => Some(2),
            _ => None,
        }
    }

    /// Index of the public threshold in `public`, if the circuit gates on age.
    pub const fn threshold_index(self) -> Option<usize> {
        match self {
            CircuitId::AgeGte => Some(5),
            CircuitId::CredentialAge => Some(3),
            _ => None,
        }
    }
}

pub const ALL: &[CircuitId] = &[
    CircuitId::AgeGte,
    CircuitId::ValidOwner,
    CircuitId::JurisdictionAllowed,
    CircuitId::CredentialAge,
];
