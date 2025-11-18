## Moores Lab AI Engineering Guidance (specific to this fork)

### Keeping this fork in sync with upstream

This repository is a fork of the public `openai/codex` repo with some additional constraints (for example: no OpenSSL, no Sentry uploads, no non–OpenAI HTTP by default). When pulling in upstream changes, keep our local behavior on top:

1. **Set up the upstream remote (once per clone)**:

   ```bash
   cd /your/path/to/moore-codex
   git remote -v
   # If `upstream` is missing:
   git remote add upstream https://github.com/openai/codex.git
   ```

2. **Create a sync branch and rebase our main on upstream**:

   ```bash
   git fetch upstream

   # Work on a temporary branch so we can abort safely if needed
   git checkout main
   git pull origin main
   git checkout -b update-from-upstream-$(date +%Y%m%d) # name whatever you want

   # Replay our commits on top of upstream/main
   git rebase upstream/main
   ```

   - Resolve any conflicts **keeping the fork-specific behavior** described below.
   - Once tests pass, fast‑forward main:

   ```bash
   git checkout main
   git merge --ff-only update-from-upstream-$(date +%Y%m%d)
   git push origin main
   ```

3. **Verify we haven’t reintroduced OpenSSL or Sentry**:

   From `codex-rs`:

   ```bash
   cd /your/path/to/moore-codex/codex-rs

   # No OpenSSL:
   cargo tree -p codex-cli -i openssl-sys
   # Should print: `error: package ID specification 'openssl-sys' did not match any packages`

   # No sentry crate:
   rg 'sentry' .
   # Should only find references in historical files / docs, not in Cargo.toml or src/.
   ```

### Fork-specific behavior to preserve

- **Rustls-only HTTP/TLS**
  - `reqwest` is configured at the workspace level with `default-features = false` and `rustls-tls` enabled.
  - No crate should enable `native-tls` or `hyper-tls`; if upstream adds them, prefer the Rustls equivalents or wire through the workspace `reqwest` instead.
  - Sanity check after merges:

    ```bash
    cargo tree -p codex-cli -i native-tls
    cargo tree -p codex-cli -i hyper-tls
    ```

- **Feedback uploads are local-only**
  - `codex-feedback` keeps an in‑memory ring buffer and can write snapshots to a temp file.
  - `CodexLogSnapshot::upload_feedback` is intentionally a no‑op; we do **not** send logs to Sentry or any other remote endpoint in this fork.

- **No Sentry dependency**
  - `sentry` is not present in `codex-rs/Cargo.toml` or `codex-rs/feedback/Cargo.toml`.
  - If upstream reintroduces Sentry for telemetry, do **not** add it back here unless we explicitly decide to.

- **No non–OpenAI HTTP by default**
  - **TUI GitHub/Homebrew update checks** are disabled unless `CODEX_ENABLE_UPDATE_CHECKS` is set in the environment.
    - This prevents background requests to GitHub and raw.githubusercontent.com in hardened environments.
  - **OAuth ChatGPT login (auth.openai.com)** is disabled unless `CODEX_ENABLE_OAUTH_LOGIN` is set.
    - Affected entrypoints:
      - `codex-rs/cli/src/login.rs` (`run_login_with_chatgpt`, `run_login_with_device_code`)
      - `codex-rs/tui/src/onboarding/auth.rs` (`start_chatgpt_login`)
    - API‑key login remains fully supported and is the default assumption for this fork.
  - LM Studio, Ollama, and OSS providers only talk to endpoints you configure (typically `localhost`); they do not introduce third‑party Internet calls.

When resolving conflicts during an upstream rebase, ensure any new HTTP clients follow these rules (Rustls, no Sentry, no new external hosts without an explicit gate).

### Building `codex` on Rocky Linux 8 (recommended)

For maximum compatibility with our target environments, we build the `codex` binary on Rocky Linux 8 inside Docker. This produces a binary that works consistently across our fleet.

From the host (outside Docker), the simplest way is to use the helper script (requires Docker installed and running):

```bash
./scripts/build-codex-rocky8.sh /your/path/to/mooreplatformbe
```

Under the hood, this runs a `rockylinux:8` container, installs the Rust toolchain defined by `codex-rs/rust-toolchain.toml`, builds `codex-cli`, and copies the resulting binary into `mooreCube/bin/codex/codex` inside the Moore platform tree.

If you prefer to run the Docker command manually, it is equivalent to:

```bash
docker run --rm \
  -v /your/path/to/moore-codex:/src \
  -v /your/path/to/mooreplatformbe:/app \
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

    # Move over to the Moore Platform BE tree (optional)
    cp target/release/codex /app/mooreCube/bin/codex/codex && \
    chmod +x /app/mooreCube/bin/codex/codex
  '
```

- **Paths**:
  - `/your/path/to/moore-codex` is the root of this fork.
  - `/your/path/to/mooreplatformbe` is the Moore platform repo that expects the `codex` binary at `/app/mooreCube/bin/codex/codex` inside the container.
- **Toolchain**:
  - The exact Rust version is controlled by `codex-rs/rust-toolchain.toml`; using `rustup` inside the container ensures we pick that up.
- **Post-build checks**:
  - Optionally, from `/src/codex-rs` inside the container:

    ```bash
    cargo tree -p codex-cli -i openssl-sys
    # Should report that `openssl-sys` does not match any packages
    ```

If you need a different install path inside the platform repo, adjust the `cp` and `chmod` lines accordingly.

- **Docker install**:
  - If you don’t already have Docker installed, follow the official installation guides for your platform at the [Docker documentation](https://docs.docker.com/get-docker/).

---



## Original README:

<p align="center"><code>npm i -g @openai/codex</code><br />or <code>brew install --cask codex</code></p>

<p align="center"><strong>Codex CLI</strong> is a coding agent from OpenAI that runs locally on your computer.
</br>
</br>If you want Codex in your code editor (VS Code, Cursor, Windsurf), <a href="https://developers.openai.com/codex/ide">install in your IDE</a>
</br>If you are looking for the <em>cloud-based agent</em> from OpenAI, <strong>Codex Web</strong>, go to <a href="https://chatgpt.com/codex">chatgpt.com/codex</a></p>

<p align="center">
  <img src="./.github/codex-cli-splash.png" alt="Codex CLI splash" width="80%" />
  </p>

---

## Quickstart

### Installing and running Codex CLI

Install globally with your preferred package manager. If you use npm:

```shell
npm install -g @openai/codex
```

Alternatively, if you use Homebrew:

```shell
brew install --cask codex
```

Then simply run `codex` to get started:

```shell
codex
```

If you're running into upgrade issues with Homebrew, see the [FAQ entry on brew upgrade codex](./docs/faq.md#brew-upgrade-codex-isnt-upgrading-me).

<details>
<summary>You can also go to the <a href="https://github.com/openai/codex/releases/latest">latest GitHub Release</a> and download the appropriate binary for your platform.</summary>

Each GitHub Release contains many executables, but in practice, you likely want one of these:

- macOS
  - Apple Silicon/arm64: `codex-aarch64-apple-darwin.tar.gz`
  - x86_64 (older Mac hardware): `codex-x86_64-apple-darwin.tar.gz`
- Linux
  - x86_64: `codex-x86_64-unknown-linux-musl.tar.gz`
  - arm64: `codex-aarch64-unknown-linux-musl.tar.gz`

Each archive contains a single entry with the platform baked into the name (e.g., `codex-x86_64-unknown-linux-musl`), so you likely want to rename it to `codex` after extracting it.

</details>

### Using Codex with your ChatGPT plan

<p align="center">
  <img src="./.github/codex-cli-login.png" alt="Codex CLI login" width="80%" />
  </p>

Run `codex` and select **Sign in with ChatGPT**. We recommend signing into your ChatGPT account to use Codex as part of your Plus, Pro, Team, Edu, or Enterprise plan. [Learn more about what's included in your ChatGPT plan](https://help.openai.com/en/articles/11369540-codex-in-chatgpt).

You can also use Codex with an API key, but this requires [additional setup](./docs/authentication.md#usage-based-billing-alternative-use-an-openai-api-key). If you previously used an API key for usage-based billing, see the [migration steps](./docs/authentication.md#migrating-from-usage-based-billing-api-key). If you're having trouble with login, please comment on [this issue](https://github.com/openai/codex/issues/1243).

### Model Context Protocol (MCP)

Codex can access MCP servers. To configure them, refer to the [config docs](./docs/config.md#mcp_servers).

### Configuration

Codex CLI supports a rich set of configuration options, with preferences stored in `~/.codex/config.toml`. For full configuration options, see [Configuration](./docs/config.md).

---

### Docs & FAQ

- [**Getting started**](./docs/getting-started.md)
  - [CLI usage](./docs/getting-started.md#cli-usage)
  - [Slash Commands](./docs/slash_commands.md)
  - [Running with a prompt as input](./docs/getting-started.md#running-with-a-prompt-as-input)
  - [Example prompts](./docs/getting-started.md#example-prompts)
  - [Custom prompts](./docs/prompts.md)
  - [Memory with AGENTS.md](./docs/getting-started.md#memory-with-agentsmd)
- [**Configuration**](./docs/config.md)
  - [Example config](./docs/example-config.md)
- [**Sandbox & approvals**](./docs/sandbox.md)
- [**Authentication**](./docs/authentication.md)
  - [Auth methods](./docs/authentication.md#forcing-a-specific-auth-method-advanced)
  - [Login on a "Headless" machine](./docs/authentication.md#connecting-on-a-headless-machine)
- **Automating Codex**
  - [GitHub Action](https://github.com/openai/codex-action)
  - [TypeScript SDK](./sdk/typescript/README.md)
  - [Non-interactive mode (`codex exec`)](./docs/exec.md)
- [**Advanced**](./docs/advanced.md)
  - [Tracing / verbose logging](./docs/advanced.md#tracing--verbose-logging)
  - [Model Context Protocol (MCP)](./docs/advanced.md#model-context-protocol-mcp)
- [**Zero data retention (ZDR)**](./docs/zdr.md)
- [**Contributing**](./docs/contributing.md)
- [**Install & build**](./docs/install.md)
  - [System Requirements](./docs/install.md#system-requirements)
  - [DotSlash](./docs/install.md#dotslash)
  - [Build from source](./docs/install.md#build-from-source)
- [**FAQ**](./docs/faq.md)
- [**Open source fund**](./docs/open-source-fund.md)

---

## License

This repository is licensed under the [Apache-2.0 License](LICENSE).
