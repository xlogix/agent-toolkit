# Agent Toolkit

## The Real Bottleneck

AI coding conversations usually focus on model capability, but real delivery speed is often gated somewhere else. During implementation, agents repeatedly run local repository commands for search, file discovery, parsing, diffing, and validation. Those loops depend on CLI latency, and even small command delays compound over dozens or hundreds of iterations. This project focuses on accelerating that local loop so model output translates into faster real-world task completion.  
> The model isn't always the bottleneck. The local tool loop often is.

<p align="center">
  <img src="./assets/agenttools-assemble-hero.png" alt="AgentTools Assemble hero banner with logo." />
</p>

**A high-performance local toolchain for coding agents.**  
When LLM agents work on real repositories, they spend most of their time in repeated local loops: discover files, search code, parse config, diff output, and validate changes. This project gives those loops faster primitives.

---

## Start in 60 Seconds

LLM quick onboarding (knowledge-first, no install required):

1. Load [skills/SKILL.md](./skills/SKILL.md).
2. Load the generated catalog: [skills/references/TOOL-CATALOG.md](./skills/references/TOOL-CATALOG.md).
3. Ask the agent for a minimal task-specific stack (for example: discovery, refactor, API debug, observability).

Install path (macOS/Linux):

```bash
chmod +x ./agent-tools.sh
./agent-tools.sh install --profiles core
./agent-tools.sh doctor
```

Install path (Windows):

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

Need help choosing packs? See **Pick Your Profile Fast** below.

Quick verification:

```bash
./agent-tools.sh doctor
./agent-tools.sh profiles
```

---

## Pick Your Profile Fast

| If your workflow is mostly... | Start with | Then add |
|---|---|---|
| general coding-agent loops and repo search | `--profiles core` | `quality` |
| frontend + media workflows | `--profiles core,ui` | `api` |
| API/service debugging | `--profiles core,api` | `infra` |
| automation/devops | `--profiles core,infra` | `quality` |
| full workstation setup | _(omit `--profiles`)_ | tune with `--add` / `--remove` |

Examples:

```bash
./agent-tools.sh install --profiles core,api
./agent-tools.sh install --profiles core,quality --add httpie --remove lazygit
```

---

## Who This Is For

- engineering teams shipping with AI coding agents
- solo builders who want faster local agent loops
- platform/devex teams standardizing agent tooling across OSes

---

## Minimal Footprint Experiment

This repo now supports a **lean install model** to avoid bloat and save space:

- install only what you need via capability packs
- combine packs when workflows overlap
- manually add/remove tools from the final set
- if you skip profiles, all packs are installed for convenience

Profiles are **not exclusive roles**.
Example: a frontend engineer can still include `api` tools for response testing.

Available packs:

- `core`: repository discovery, search, and parsing tools
- `ui`: frontend development and asset tooling
- `api`: debugging and inspecting service endpoints
- `infra`: environment automation utilities
- `quality`: linting, benchmarking, and validation tools

---

## Why This Exists

LLM coding agents are often bottlenecked by local command performance, not model speed.

These tools already exist as standalone utilities, but setting them up consistently across developer machines and package managers is still a practical challenge. AgentTools Assemble solves that by installing a curated, agent-optimized CLI environment with one workflow.

In a typical edit cycle, agents repeatedly do:

1. Locate relevant files
2. Search for symbols/config/strings
3. Parse structured data (`json`, `yaml`, `toml`)
4. Inspect diffs and logs
5. Repeat until tests pass

If each loop is 2x faster, end-to-end task completion can improve dramatically over long sessions.

---

## The Agent Development Loop

```text
Search repository
  ↓
Load context
  ↓
Modify code
  ↓
Run validation
  ↓
Repeat
```

This loop can run dozens or hundreds of times in a single task. Each step relies on local CLI commands, and command latency compounds across every iteration.

---

## Agent Infrastructure Layer

```text
LLM
↓
Agent framework
↓
CLI primitives (AgentTools Assemble)
↓
Operating system
```

AgentTools Assemble optimizes the CLI primitive layer used by agents between planning and execution.

---

## Agent Capability Stack

> These tools are not random utilities. They represent the core primitives agents repeatedly call when interacting with repositories, APIs, and local environments.

Repository discovery and search:
`ripgrep (rg)`, `fd`, `fzf`

Structured data inspection:
`jq`, `yq`

Code understanding and transformation:
`ast-grep`, `sd`, `git-delta`, `difftastic`, `bat`

Automation and benchmarking:
`hyperfine`, `just`, `watchexec`, `shellcheck`, `direnv`

Networking and API interaction:
`httpie`, `grpcurl`, `gh`

System diagnostics and workflow visibility:
`lazygit`

Developer navigation:
`eza`, `zoxide`

Frontend/media and multimodal asset workflows:
`ImageMagick`, `ffmpeg`, `tesseract`

No-profile install includes all packs.
Use `--profiles core` for a minimal/space-saving setup.

Additional candidate tools and rollout notes:
[docs/TOOL-CANDIDATES.md](./docs/TOOL-CANDIDATES.md)

---

## Real Performance Gains

Measured locally on **Apple M3 Pro / macOS 26.3 / hyperfine 1.20.0** (40 runs, 8 warmups, date: 2026-03-05).
The benchmark corpus includes roughly 30k+ files across text, TypeScript, markdown, JSON, and YAML workloads to reflect mixed-repository agent loops.

Recursive search: `grep -R` vs `rg` -> **2.83x faster**  
File discovery: `find` vs `fd` -> **1.86x faster**  
Find + grep pipeline: `find ... -exec grep` vs `rg -g` -> **3.57x faster**

| Workflow | Baseline | Agent tool | Mean baseline | Mean with agent tool | Speedup |
|---|---|---|---:|---:|---:|
| Recursive content search | `grep -R` | `rg` | 268.4 ms | 95.0 ms | **2.83x** |
| File discovery | `find -name "*.ts"` | `fd -e ts` | 33.1 ms | 17.9 ms | **1.86x** |
| Find + grep pipeline | `find ... -exec grep` | `rg -g "*.ts"` | 239.2 ms | 67.1 ms | **3.57x** |
| Structured search | `rg` | `ast-grep` | 345.1 ms | 66.5 ms | **5.19x** |
| JSON query | `python3` | `jq` | 177.4 ms | 41.3 ms | **4.30x** |
| Search + replace | `sed` | `sd` | 73.6 ms | 29.7 ms | **2.48x** |

These commands appear frequently inside agent edit--validate loops.

Full benchmark methodology and reproduction commands: [docs/BENCHMARKS.md](./docs/BENCHMARKS.md)
Latest run artifacts: [benchmarks/results/20260305](./benchmarks/results/20260305)

Run the scientific benchmark harness with configurable warmups/runs:

```bash
bash scripts/benchmarks/run-scientific-benchmarks.sh --runs 40 --warmup 8
```

---

## Quick Start

### Interactive CLI Menu (macOS/Linux)

```bash
chmod +x ./agent-tools.sh
./agent-tools.sh menu
```

The menu includes a formatted header, live environment summary, and quick actions.

The menu supports:

- Install core tools
- Install extras
- Update existing packages
- Reinstall packages
- Install additional packages
- Run diagnostics/fix suggestions
- Initialize `.gitignore` in the current repo

### Non-interactive Commands (macOS/Linux)

```bash
./agent-tools.sh install --profiles core
./agent-tools.sh install --profiles core,ui,api
./agent-tools.sh install --profiles core --add httpie --add grpcurl
./agent-tools.sh install --profiles core,quality --remove lazygit
./agent-tools.sh update --profiles core,api
./agent-tools.sh reinstall --profiles core,quality
./agent-tools.sh profiles
./agent-tools.sh add uv pnpm
./agent-tools.sh doctor
./agent-tools.sh init
```

`init` writes/patches `.gitignore` in the repo where you run it (or pass `--repo <path>`).
`--extras` is still available as a shortcut to add `ui,api,infra,quality` packs.

Option `7` in the interactive menu (or `./agent-tools.sh init`) adds:

```text
tmp/
.generated/
.claude/
.playwright-cli/
coverage/
test-results/
artifacts/
*.log
```

---

## One-command Installers

### macOS + Linux installer

```bash
chmod +x ./install.sh
./install.sh
./install.sh --profiles core,ui,api
./install.sh --profiles core --add httpie --add grpcurl
./install.sh --profiles core,quality --remove lazygit
./install.sh --extras
```

Direct URL:

```bash
curl -fsSL https://raw.githubusercontent.com/xlogix/agent-toolkit/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/xlogix/agent-toolkit/main/install.sh | bash -s -- --extras
```

### Windows installer

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
.\install.ps1 -Extras
```

Direct URL:

```powershell
irm https://raw.githubusercontent.com/xlogix/agent-toolkit/main/install.ps1 | iex
```

---

## Supported Package Managers

- macOS: `brew`
- Linux: `apt`, `dnf`, `pacman`, `zypper`, `apk`
- Windows: `winget`, `choco`, `scoop`

---

## Repository Layout

- [agent-tools.sh](./agent-tools.sh): interactive CLI manager (install/update/reinstall/add/doctor/init)
- [install.sh](./install.sh): macOS/Linux installer
- [install.ps1](./install.ps1): Windows installer
- [scripts/install-agent-tools.sh](./scripts/install-agent-tools.sh): compatibility wrapper
- [scripts/release-prep.sh](./scripts/release-prep.sh): checksum helper for releases
- [docs/PUBLISHING.md](./docs/PUBLISHING.md): packaging/publishing workflow
- [packaging/](./packaging): Homebrew/Scoop/Chocolatey templates

---

## Troubleshooting

- If `ffmpeg` resolves to a legacy `ffmpeg@6` path on macOS, prefer `/opt/homebrew/bin/ffmpeg`.
- On Debian/Ubuntu, `fd` may be `fdfind` and `bat` may be `batcat`.
- Run diagnostics with `./agent-tools.sh doctor`.

---

## Publishing

Versioning follows CalVer tags: `vYYYY.MM.DD` (optionally `vYYYY.MM.DD.N` for same-day follow-up releases).

Use [docs/PUBLISHING.md](./docs/PUBLISHING.md) to publish updates across package manager ecosystems.

---

## Contributing

Contributions are welcome and encouraged.

- Guide: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Collaboration playbook (for humans + coding agents): [AGENTS.md](./AGENTS.md)
- Code of Conduct: [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- License: [LICENSE](./LICENSE)

For quick onboarding:

```bash
./agent-tools.sh --help
./agent-tools.sh menu
```

## Closing

Coding agents depend heavily on local tooling to iterate quickly and safely. Faster CLI primitives directly improve workflow speed across real repository tasks.

Faster primitives make faster agents.

---

Created by **Abhishek Uniyal** (`xlogix`).
