"""
veritas_harness.py — shared helpers for the Veritas circuit test suite.

The circom circuits need BabyJubJub / EdDSA / Poseidon / Merkle crypto that is
fiddly to reimplement in pure Python. We delegate that to the reference
`circomlibjs` via the Node CLI `scripts/zk_helpers.js`, then orchestrate witness
generation, Groth16 proving and verification through the `snarkjs` CLI. This
keeps the test logic in Python while guaranteeing the crypto exactly matches what
the circuits expect.

All field elements flow as DECIMAL STRINGS (the format circom / snarkjs expect).

CLI:
    python3 circuits/test/veritas_harness.py        # run the self-test matrix
    python3 -m pytest circuits/test                 # run the pytest suite

Public signal order convention (snarkjs): OUTPUTS first, then declared public
inputs in source order. See circuits/README.md for the per-circuit table.
"""
from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------
# this file lives at  <repo>/circuits/test/veritas_harness.py
ROOT = Path(__file__).resolve().parents[2]          # builds/veritas-zk/
CIRCUITS = ROOT / "circuits"
SCRIPTS = ROOT / "scripts"
HELPER = SCRIPTS / "zk_helpers.js"
NODE_MODULES = CIRCUITS / "node_modules"

# issuer private key used across every test (TEST ONLY — never reuse in prod).
# fixed so proofs are deterministic and reproducible.
TEST_ISSUER_PRV = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"


# ----------------------------------------------------------------------------
# Errors
# ----------------------------------------------------------------------------
class VeritasError(Exception):
    """Base error for the harness."""


class WitnessError(VeritasError):
    """Raised when witness generation fails (the circuit is unsatisfiable).

    This is the EXPECTED outcome for negative tests: no valid witness can be
    produced, therefore no proof can ever exist for a bad credential.
    """


class BuildMissing(VeritasError):
    """Raised when a circuit has not been compiled / set up yet."""


# ----------------------------------------------------------------------------
# Circuit metadata
# ----------------------------------------------------------------------------
@dataclass(frozen=True)
class Circuit:
    name: str            # directory under circuits/
    base: str            # artifact basename (trivial uses "preimage", others = name)

    @property
    def dir(self) -> Path:
        return CIRCUITS / self.name

    @property
    def build(self) -> Path:
        return self.dir / "build"

    @property
    def wasm(self) -> Path:
        return self.build / f"{self.base}_js" / f"{self.base}.wasm"

    @property
    def zkey(self) -> Path:
        return self.build / f"{self.base}_final.zkey"

    @property
    def vk(self) -> Path:
        return self.build / "verification_key.json"

    def assert_built(self) -> None:
        missing = [p for p in (self.wasm, self.zkey, self.vk) if not p.exists()]
        if missing:
            names = ", ".join(str(p.relative_to(ROOT)) for p in missing)
            raise BuildMissing(
                f"circuit '{self.name}' is not built. Missing: {names}.\n"
                f"  Run:  ./scripts/build_circuit.sh {self.name} <ptau_power>"
            )


def circuit(name: str) -> Circuit:
    base = "preimage" if name == "trivial" else name
    return Circuit(name=name, base=base)


# ----------------------------------------------------------------------------
# Subprocess glue
# ----------------------------------------------------------------------------
def _run(cmd: Iterable[str], *, env_extra: dict[str, str] | None = None,
         timeout: int = 120) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        list(cmd), capture_output=True, text=True, env=env, timeout=timeout,
    )


def snarkjs(*args: str) -> subprocess.CompletedProcess:
    """Run a snarkjs subcommand, returning the completed process."""
    return _run(["snarkjs", *args])


def node_helper(cmd: str, *args: str) -> dict[str, Any]:
    """Invoke scripts/zk_helpers.js <cmd> and parse the single JSON line it prints.

    circomlibjs is installed under circuits/node_modules, so we expose it to the
    script (which lives in scripts/) via NODE_PATH.
    """
    cp = _run(
        ["node", str(HELPER), cmd, *args],
        env_extra={"NODE_PATH": str(NODE_MODULES)},
        timeout=60,
    )
    if cp.returncode != 0:
        raise VeritasError(
            f"zk_helpers.js {cmd} failed (exit {cp.returncode}):\n{cp.stderr.strip()}"
        )
    # helper prints exactly one JSON object on stdout
    line = cp.stdout.strip().splitlines()[-1]
    return json.loads(line)


def genkey(prv: str = TEST_ISSUER_PRV) -> dict[str, str]:
    return node_helper("genkey", "--prv", prv)


def sign(field: int | str, secret: int | str, prv: str = TEST_ISSUER_PRV) -> dict[str, str]:
    """EdDSA-Poseidon sign Poseidon(field, secret) -> returns pubkey + sig + nullifier + msg."""
    return node_helper("sign", "--prv", prv, "--field", str(field), "--secret", str(secret))


def poseidon(*vals: int | str) -> str:
    res = node_helper("poseidon", "--args", ",".join(str(v) for v in vals))
    return res["out"]


def merkle(depth: int, members: Iterable[int], prove_index: int) -> dict[str, Any]:
    members_str = ",".join(str(m) for m in members)
    return node_helper("merkle", "--depth", str(depth), "--members", members_str,
                       "--prove", str(prove_index))


# ----------------------------------------------------------------------------
# Witness / proof / verify
# ----------------------------------------------------------------------------
def gen_witness(c: Circuit, inputs: dict[str, Any], workdir: Path) -> Path:
    """Generate a witness. Raises WitnessError if the circuit is unsatisfiable."""
    c.assert_built()
    workdir = Path(workdir)
    workdir.mkdir(parents=True, exist_ok=True)
    inp = workdir / "input.json"
    wtns = workdir / "witness.wtns"
    inp.write_text(json.dumps(inputs))
    cp = snarkjs("wc", str(c.wasm), str(inp), str(wtns))
    if cp.returncode != 0:
        # snarkjs prints the constraint that failed on stderr; surface it.
        detail = (cp.stderr or cp.stdout).strip().splitlines()
        # keep the most informative lines (template trace)
        detail = [d for d in detail if d.strip()][:4]
        raise WitnessError(
            f"[{c.name}] witness generation FAILED — circuit unsatisfiable.\n"
            + "\n".join("    " + d for d in detail)
        )
    return wtns


def prove(c: Circuit, wtns: Path, workdir: Path) -> tuple[Path, Path]:
    """Groth16 prove. Returns (proof.json, public.json)."""
    c.assert_built()
    workdir = Path(workdir)
    proof = workdir / "proof.json"
    public = workdir / "public.json"
    cp = snarkjs("groth16", "prove", str(c.zkey), str(wtns), str(proof), str(public))
    if cp.returncode != 0:
        raise VeritasError(f"[{c.name}] groth16 prove failed:\n{cp.stderr.strip()}")
    return proof, public


def verify(c: Circuit, public: Path, proof: Path) -> bool:
    """Groth16 verify. Returns True/False."""
    c.assert_built()
    cp = snarkjs("groth16", "verify", str(c.vk), str(public), str(proof))
    ok = cp.returncode == 0 and "OK!" in (cp.stdout + cp.stderr)
    return ok


def read_public(public_json: Path) -> list[str]:
    return json.loads(Path(public_json).read_text())


def full_cycle(c: Circuit, inputs: dict[str, Any], workdir: Path) -> tuple[list[str], bool]:
    """End-to-end: witness -> prove -> verify. Returns (public_signals, verified)."""
    wtns = gen_witness(c, inputs, workdir)
    proof, public = prove(c, wtns, workdir)
    return read_public(public), verify(c, public, proof)


def expects_pass(c: Circuit, inputs: dict[str, Any], label: str, *,
                 workdir: Path | None = None) -> list[str]:
    """Assert a valid proof is produced + verifies. Returns the public signals."""
    workdir = workdir or (CIRCUITS / "test" / "_work" / c.name / label)
    pubs, ok = full_cycle(c, inputs, workdir)
    assert ok, f"[{c.name}/{label}] proof did NOT verify (expected PASS)"
    return pubs


def expects_reject(c: Circuit, inputs: dict[str, Any], label: str, *,
                   workdir: Path | None = None) -> None:
    """Assert witness generation FAILS (no proof can exist)."""
    workdir = workdir or (CIRCUITS / "test" / "_work" / c.name / label)
    try:
        gen_witness(c, inputs, workdir)
    except WitnessError:
        return  # expected: unsatisfiable
    raise AssertionError(
        f"[{c.name}/{label}] witness SUCCEEDED for a credential that MUST be rejected"
    )


__all__ = [
    "Circuit", "circuit", "ROOT", "TEST_ISSUER_PRV",
    "VeritasError", "WitnessError", "BuildMissing",
    "genkey", "sign", "poseidon", "merkle",
    "gen_witness", "prove", "verify", "full_cycle",
    "expects_pass", "expects_reject", "read_public",
]
