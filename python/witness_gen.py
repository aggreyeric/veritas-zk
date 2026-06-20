#!/usr/bin/env python3
"""Generate witnesses from circom WASM."""
import subprocess, json, os, sys

CIRCUITS_DIR = os.path.join(os.path.dirname(__file__), "..", "circuits", "build")

def generate_witness(circuit_name, input_file):
    wasm_path = os.path.join(CIRCUITS_DIR, f"{circuit_name}_js", f"{circuit_name}.wasm")
    out_path = os.path.join(CIRCUITS_DIR, f"{circuit_name}_js", "witness.wtns")
    subprocess.run(["node", os.path.join(CIRCUITS_DIR, f"{circuit_name}_js", "generate_witness.js"),
                    wasm_path, input_file, out_path], check=True)
    print(f"Generated witness: {out_path}")

if __name__ == "__main__":
    for name in ["AgeGte", "JurisdictionAllowed", "ValidOwner"]:
        inp = os.path.join(CIRCUITS_DIR, f"{name.lower()}_input.json".replace("gte","gte").replace("jurisdictionallowed","jurisdiction_allowed").replace("validowner","valid_owner"))
        if os.path.exists(inp):
            generate_witness(name, inp)
