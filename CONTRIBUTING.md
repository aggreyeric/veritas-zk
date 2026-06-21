# Contributing to Veritas

Thanks for your interest in Veritas — the privacy-preserving ZK credential verifier for Stellar /
Soroban. Contributions are welcome, from circuit tweaks to Soroban contract work.

> **Read [`README.md`](README.md) first.** It covers the architecture, the end-to-end demo, the test
> layout, and deploy commands. This guide assumes you've done that.

## Prerequisites

- **Node.js 18+** and npm — the JS toolchain (circomlibjs, snarkjs)
- **Python 3.10+** — the alternative Python toolchain under `python/`
- **circom 2.x** and **snarkjs** — for circuit development and proof generation
- *For Soroban contract work:* Rust, the `wasm32v1-none` target, and the `stellar` CLI

## Setup

```bash
git clone https://github.com/<your-fork>/veritas-zk.git
cd veritas-zk
npm install                                   # JS toolchain
pip install -r python/requirements.txt        # Python toolchain
```

## Running tests

```bash
npm test                  # JS / Groth16 circuits
python -m pytest tests/   # Python toolchain
```

The end-to-end demo and the Soroban contract tests are documented in `README.md`
(`scripts/demo.sh` and `cargo test` inside `soroban/contracts/veritas-verifier`).
Ensure **all tests pass** before opening a PR.

## Circuit development workflow

1. **Edit** a `.circom` file under `circuits/` (e.g. `AgeGte.circom`).
2. **Compile** the circuit: `bash scripts/build_circuit.sh <CircuitName>`.
3. **Generate** a Groth16 proof via `bash scripts/verify_all.sh` or
   `node services/prover/prove.js <CircuitName>`.
4. **Verify** off-chain (snarkjs) and on-chain (Soroban sandbox) via `bash scripts/demo.sh`.

An invalid predicate makes a circuit **unsatisfiable** — no proof can exist. If you change a
circuit, regenerate the verifying key and update the on-chain `set_verifying_key` binding.

## Code style

- **JavaScript/Node:** ESLint. Keep helper scripts consistent with `scripts/`.
- **Python:** [Black](https://github.com/psf/black).
- **Rust (Soroban):** `cargo fmt` and `cargo clippy`.

## Pull request process

1. **Fork** the repo and create a branch: `git checkout -b feat/my-change`.
2. **Write tests** and ensure the full suite is green.
3. **Open a PR** with a clear description of what changed and why. Link any relevant issue.
4. Keep PRs focused — one feature or fix per PR.

## License

By contributing you agree that your contributions are licensed under the **MIT License**
(see [`LICENSE`](LICENSE)).
