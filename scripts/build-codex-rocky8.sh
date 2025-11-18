#!/usr/bin/env bash
set -euo pipefail

# Build the codex CLI binary inside a Rocky Linux 8 container.
# Usage:
#   ./scripts/build-codex-rocky8.sh /your/path/to/mooreplatformbe
#
# This script assumes:
# - You are running it from the forked moore-codex repo.
# - The Moore platform backend repo is passed as the first argument and expects
#   the codex binary at mooreCube/bin/codex/codex.

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/mooreplatformbe" >&2
  exit 1
fi

PLATFORM_DIR="$1"

if [[ ! -d "$PLATFORM_DIR" ]]; then
  echo "Error: PLATFORM_DIR '$PLATFORM_DIR' does not exist or is not a directory." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker run --rm \
  -v "${REPO_ROOT}":/src \
  -v "${PLATFORM_DIR}":/app \
  -w /src/codex-rs \
  rockylinux:8 \
  bash -lc '
    set -euo pipefail

    dnf -y groupinstall "Development Tools" && \
    dnf -y install curl git pkgconfig openssl-devel && \

    # Install Rust (we rely on the workspace rust-toolchain.toml for the exact version)
    curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    source "$HOME/.cargo/env" && \

    # Build the CLI binary
    cargo build -p codex-cli --release && \

    # Install into the Moore platform tree
    cp target/release/codex /app/mooreCube/bin/codex/codex && \
    chmod +x /app/mooreCube/bin/codex/codex
  '

echo "Built codex and installed it to ${PLATFORM_DIR}/mooreCube/bin/codex/codex"
