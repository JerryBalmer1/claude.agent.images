# claude.agent.images

Born from claude.pwsh.image.builder at 5f711736e028f0078d8b32b732ec37cb224258be; depends on claude.agent.core v0.2.0 (536cb2cdf5a56780fbb2a3066e3d724d4d06565e).

**The leash, rebuilt.** A Docker image that runs Claude Code with a PreToolUse deny gate, hash-chained receipts, and the policy outside the agent's reach — now with an Invoke-Build surface that enforces the shared plan contract.

## What this is

An agentic workflow is just an Azure DevOps pipeline where the stages are LLM calls. Same YAML, same triggers, same "stage failed = run is red" semantics. The leash is the approval gate before the deploy stage — except the deploy stage is a tool call and the approval is a hash-chained receipt.

This repo now also ships the **build surface**: `Invoke-Build` tasks that build the agent images, enforce structured plan output, run fail-first tests, and audit skills that don't exist yet.

## Quick start

```powershell
# Tab-complete tasks:
. ./build/ArgumentCompleters.ps1
Invoke-Build <TAB>

# Run the default chain:
Invoke-Build

# Or just the images:
Invoke-Build Images.Build
```

```bash
docker build -t leash .
docker run --rm -it \
  -v ./ledger:/ledger \
  -v ./work:/work \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e LEDGER_PRINCIPAL="jerry" \
  -e LEDGER_HOOK_ARM=1 \
  leash claude
```

## Build tasks

| Task | What it does |
|---|---|
| `Clean` | Remove output/ |
| `Bootstrap` | Install pinned deps (InvokeBuild, Pester, PSScriptAnalyzer) |
| `Plan.Check` | Assert plan schema + validator exist (fail-first) |
| `Images.Build` | Build developer + agent images |
| `Images.Build.Developer` | Build the developer agent image |
| `Images.Build.Agent` | Build the Azure DevOps-style agent image |
| `Test.FailFirst` | Run fail-first plan contract tests (must fail red) |
| `Skills.Audit` | List skills referenced but not built |
| `Help` | Grouped task catalog |
| `.` | Default chain: Clean → Bootstrap → Plan.Check → Images.Build → Test.FailFirst → Skills.Audit |

## The plan contract

Every plan that enters the system has a structured format:
- `id`, `steps[]`, `expected_output`, `skills_to_build[]`
- Tested before trusted (fail-first)
- Skills that don't exist are listed, not ignored

See `schemas/plan.schema.json` and `plans/README.md`.

## The snake

The Ledger snake lives in `claude.build.ledger` (sibling repo). The builder must consume it — not reimplement it. The developer image should suck it in so plan enforcement is real.

## Breadcrumbs

`.agents/BREADCRUMBS.md` has messages for Claude and Fable. They should pick up the plan contract, the fail-first discipline, and the snake integration. If they don't, they're failing at their jobs.

## Sharp edges

- Identity is operator-asserted, not signed.
- Tail truncation is detectable at boot, not prevented.
- No signing key.
- 15s hook timeout fails open.
- Auto-updater is disabled. Pin CLAUDE_CODE_VERSION at build.
- PowerShell 7.4+ is law. `$ErrorActionPreference = 'Stop'`. `$PSNativeCommandUseErrorActionPreference = $true`.
- `ConvertTo-Json` / `ConvertFrom-Json` are banned on the chain (Ledger repo). Here they're fine for plan JSON.

## Not in v0

No Kubernetes. No Helm. No ontology. No graph DB. No LLM write path. No `--dangerously-skip-permissions`. No sudo for the runtime user.
