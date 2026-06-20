#!/usr/bin/env python3
"""Generate keypair and sign credential claims for Veritas ZK."""
import json, hashlib, secrets, sys

def generate_keypair():
    privkey = secrets.token_bytes(32)
    pubkey = hashlib.sha256(privkey).digest()
    return {"private_key": privkey.hex(), "public_key": pubkey.hex()}

def sign_claim(claim: dict, private_key: str):
    claim_str = json.dumps(claim, sort_keys=True)
    claim_hash = hashlib.sha256(claim_str.encode()).hexdigest()
    sig = hashlib.sha256((private_key + claim_hash).encode()).hexdigest()
    return {"claim": claim, "claim_hash": claim_hash, "signature": sig, "signed_at": "2026-06-20"}

if __name__ == "__main__":
    kp = generate_keypair()
    claim = {"name": "Alice", "dob": "1995-03-15", "country": "US", "type": "identity"}
    signed = sign_claim(claim, kp["private_key"])
    signed["issuer_pubkey"] = kp["public_key"]
    with open("signed_credential.json", "w") as f:
        json.dump(signed, f, indent=2)
    print("Created signed_credential.json")
