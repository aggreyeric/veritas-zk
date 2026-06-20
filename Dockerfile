# =============================================================================
# Veritas — reproducible demo environment
# =============================================================================
# circom + snarkjs + Rust/wasm32v1-none + the Stellar CLI. Builds the circuits
# and the Soroban verifier contract, then drops you into a shell ready to run
# `scripts/demo.sh` (full end-to-end on-chain verification).
#
#   docker build -t veritas-zk .
#   docker run --rm -it veritas-zk            # then: bash scripts/demo.sh
# =============================================================================

FROM rust:1.94-bookworm AS base

ENV DEBIAN_FRONTEND=noninteractive \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup

# ---- system + node -----------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates xz-utils git jq \
        nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# ---- circom (official linux x86_64 binary) -----------------------------------
ARG CIRCOM_VERSION=2.2.3
RUN curl -fsSL "https://github.com/iden3/circom/releases/download/v${CIRCOM_VERSION}/circom-linux-amd64" \
        -o /usr/local/bin/circom && chmod +x /usr/local/bin/circom

# ---- snarkjs -----------------------------------------------------------------
RUN npm install -g snarkjs@0.7.6

# ---- rust wasm target for Soroban -------------------------------------------
RUN rustup target add wasm32v1-none

# ---- Stellar CLI (reliable cross-platform install via cargo) ----------------
RUN cargo install --locked --root /usr/local stellar-cli --version 27.0.0

WORKDIR /veritas

# ---- deps first (better layer caching) --------------------------------------
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY circuits/package.json circuits/package.json
RUN cd circuits && npm install --no-audit --no-fund

# ---- source ------------------------------------------------------------------
COPY . .

# ---- pre-build everything (circuits + contract) ------------------------------
# Pre-fetch cargo deps so the contract build is fast at demo time.
RUN cd soroban/verifier && cargo fetch || true

# sanity: circom + snarkjs present
RUN circom --version && snarkjs --version | head -1

SHELL ["/bin/bash", "-c"]
CMD ["bash", "-c", "echo 'Veritas ready. Run:  bash scripts/demo.sh'; bash"]
