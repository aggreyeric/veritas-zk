#!/usr/bin/env python3
"""Verify Groth16 proofs using snarkjs."""
import subprocess, json, os

CIRCUITS_DIR = os.path.join(os.path.dirname(__file__), "..", "circuits", "build")
ZKEYS_DIR = os.path.join(CIRCUITS_DIR, "zkeys")

def verify_proof(circuit_name):
    wasm_dir = os.path.join(CIRCUITS_DIR, f"{circuit_name}_js")
    vkey = os.path.join(ZKEYS_DIR, f"{circuit_name}_vkey.json")
    public = os.path.join(wasm_dir, f"{circuit_name}_public.json")
    proof = os.path.join(wasm_dir, f"{circuit_name}_proof.json")
    result = subprocess.run(["npx", "snarkjs", "groth16", "verify", vkey, public, proof], capture_output=True, text=True)
    print(f"[{circuit_name}] {result.stdout.strip()}")
    return "OK" in result.stdout

if __name__ == "__main__":
    all_ok = True
    for name in ["AgeGte", "JurisdictionAllowed", "ValidOwner"]:
        if not verify_proof(name):
            all_ok = False
    print(f"\nAll valid: {all_ok}")
