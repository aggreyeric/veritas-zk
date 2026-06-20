#!/usr/bin/env python3
"""Generate Groth16 proofs using snarkjs."""
import subprocess, json, os

CIRCUITS_DIR = os.path.join(os.path.dirname(__file__), "..", "circuits", "build")
ZKEYS_DIR = os.path.join(CIRCUITS_DIR, "zkeys")

def generate_proof(circuit_name):
    zkey = os.path.join(ZKEYS_DIR, f"{circuit_name}_final.zkey")
    wasm_dir = os.path.join(CIRCUITS_DIR, f"{circuit_name}_js")
    witness = os.path.join(wasm_dir, "witness.wtns")
    proof = os.path.join(wasm_dir, f"{circuit_name}_proof.json")
    public = os.path.join(wasm_dir, f"{circuit_name}_public.json")
    subprocess.run(["npx", "snarkjs", "groth16", "prove", zkey, witness, proof, public], check=True)
    print(f"Proof: {proof}")

if __name__ == "__main__":
    for name in ["AgeGte", "JurisdictionAllowed", "ValidOwner"]:
        generate_proof(name)
