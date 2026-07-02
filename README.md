# Stack Setup Curated

**Source-locked setup auditing for AI coding agents.**

[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-blue)](https://agentskills.io/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

This repository is a focused skill bundle for setting up, auditing, and safely
porting AI coding-agent workflows. It is not a giant skill marketplace and it is
not an "install everything" script. The niche is narrower: keep a small set of
high-value skills in a reviewed repo, verify their hashes, sync them into Codex,
and make cross-agent setup decisions from official sources instead of guesswork.
For cross-platform setup, target-native plugins, skills, rules, commands, and
marketplaces come first. Conversion from another platform's skill is the fallback
only when the target platform lacks a native or close-equivalent option. When a
capability is missing on the target, Claude Code and Codex are reasonable first
cross-ecosystem checks, but any marketplace can be a source if the needed
skill/plugin only exists there and passes provenance, license, permission, and
runtime-feature review.

```powershell
npx skills@latest add wochaotom/Stack-Setup-Curated --list
```

Then install the specific skill you need into the agent you actually use.

## What This Gives You

| Capability | What it does |
| --- | --- |
| Curated skill source | Treats `skills/` as the source of truth and installed Codex copies as derived artifacts. |
| Lockfile integrity | Tracks every bundled skill file with SHA-256 hashes in `skills-lock.json`. |
| Tamper-aware sync | Reports installed-skill drift before replacing installed copies. |
| Skill scanning | Blocks obvious prompt-injection phrases in skill and descriptor files, dynamic PowerShell execution, fetch-and-execute patterns, and credential-shaped secrets in bundled skill files. |
| Setup audit | Audits repositories for agent setup fit across rules, skills, MCP/tools, hooks, commands, agents, automations, permissions, provenance, and verification. |
| Source review scorecard | Requires install and conversion candidates to record source authority, original source, runtime surface, permission class, conversion loss, and verification path. |
| Harness evaluation loop | Turns repeated setup failures into scanner rules, converter guards, fixtures, verifier commands, or skill instruction updates instead of broadening the stack by default. |
| Safe conversion | Converts simple skills/plugins to supported client layouts when feasible and exits nonzero when conversion would be lossy or unsupported. |

## Included Skill

| Skill | Purpose |
| --- | --- |
| `stack-setup-audit` | Read-only repo setup recommender for AI coding assistants, including cross-client capability mapping and source-authority checks. |

## Quick Start

### NPM / Marketplace Install

`npx skills@latest` is the npm install surface for this repo. The repository is
not a Node package; adding a `package.json` would imply a runtime package that
does not exist here. This is also the Agent Skills marketplace-compatible path:
install from the GitHub repo, choose the native `--agent`, and let that platform
load the skill from its own skill directory.

Direct GitHub install works as soon as the repository is public. Marketplace
install requires the repository to be accepted or indexed by the marketplace;
use the marketplace's package id instead of guessing one from the GitHub name.

List available skills:

```powershell
npx skills@latest add wochaotom/Stack-Setup-Curated --list
```

Install the setup audit skill globally:

```powershell
npx skills@latest add wochaotom/Stack-Setup-Curated --skill stack-setup-audit --agent codex --global --yes
```

Install for another native Agent Skills client:

```powershell
npx skills@latest add wochaotom/Stack-Setup-Curated --skill stack-setup-audit --agent claude-code --global --yes
npx skills@latest add wochaotom/Stack-Setup-Curated --skill stack-setup-audit --agent cursor --global --yes
npx skills@latest add wochaotom/Stack-Setup-Curated --skill stack-setup-audit --agent github-copilot --global --yes
```

Install the bundled skill to all agents detected by the CLI only after
reviewing the target list:

```powershell
npx skills@latest add wochaotom/Stack-Setup-Curated --all --yes
```

Marketplace search and install:

```powershell
npx skills@latest find setup-audit
npx agent-skills-cli search setup-audit
npx agent-skills-cli install <marketplace-skill-id> -a codex
npx agent-skills-cli install <marketplace-skill-id> -a claude,cursor,copilot
```

Use marketplace install for discovery and convenience, then apply the same
source review as a GitHub install: verify the original repo, maintainer,
license, scripts, permissions, and pinned version before installing broadly.

### Local Codex Sync

```powershell
git clone https://github.com/wochaotom/Stack-Setup-Curated.git
cd Stack-Setup-Curated
& .\scripts\sync_skills.ps1
```

The sync path:

1. scans bundled skill files,
2. verifies `skills-lock.json`,
3. reports installed drift,
4. copies repo skills into `C:\Users\<you>\.codex\skills`,
5. verifies installed file hashes,
6. runs installed setup-audit tests.

### Audit A Repo

```powershell
& .\skills\stack-setup-audit\scripts\audit.ps1 -Path C:\path\to\SomeRepo
```

Focus one mechanism:

```powershell
& .\skills\stack-setup-audit\scripts\audit.ps1 -Path C:\path\to\SomeRepo -Focus hooks
```

Machine-readable output:

```powershell
& .\skills\stack-setup-audit\scripts\audit.ps1 -Path C:\path\to\SomeRepo -Json
```

### Convert A Skill

List supported targets:

```powershell
& .\skills\stack-setup-audit\scripts\convert_skill.ps1 -ListTargets -Json
```

Convert a portable skill to GitHub Copilot's skill layout:

```powershell
& .\skills\stack-setup-audit\scripts\convert_skill.ps1 `
  -SourcePath .\skills\stack-setup-audit `
  -Target github-copilot `
  -OutputPath .\out\converted `
  -Json
```

Blocked and unsupported conversions return JSON and exit nonzero, so CI and
automation can fail fast instead of reading a false-success process exit.

### Native-First Discovery

When auditing or preparing setup for a platform:

1. Search that platform's own official marketplace, built-in plugins, native
   skills, rules, commands, agents, hooks, MCP docs, and extension model first.
2. If there is no exact native match, look for a close target-native equivalent
   that can be configured safely.
3. Only when the target platform lacks a native or adjacent option, inspect
   cross-ecosystem sources. Check Claude Code and Codex first when they are
   likely to have mature coverage, then inspect any other marketplace if the
   needed skill/plugin only exists there.
4. Treat marketplace-only sources as untrusted until reviewed: inspect the
   original repository, maintainer, license, scripts, install steps, network
   calls, permissions, and pinned version.
5. Block conversion when platform-exclusive features would be dropped: MCP
   servers, hooks, auth, tools, agents, scripts, assets, apps, or other runtime
   behavior.

Conversion is a bridge for gaps, not the default acquisition path.

### Minimal Install Policy

Install the smallest reviewed thing that satisfies the active workflow.

1. Install one native skill/plugin for the current job, not a broad stack.
2. Prefer narrow domain bundles over complete bundles.
3. Prefer linking or converting a pattern over installing a risky runtime
   package when scripts, tools, auth, hooks, MCP servers, or legal/cyber
   high-risk behavior are not needed.
4. Do not add MCP servers, hooks, automations, agents, commands, or background
   services unless the workflow needs them now and the user approves.
5. Pin and review community marketplace sources before install.
6. Remove or avoid stale, unused, duplicate, or overlapping setup.

The default answer should be "no install yet" until the audit has a concrete
workflow, target client, source, safety review, and verification path.

## Supported Adapter Targets

The audit and converter reason about these clients:

- Codex
- Claude Code
- GitHub Copilot
- Cursor
- Google Antigravity
- Gemini CLI
- OpenCode
- Aider
- Continue
- Cline
- Roo Code
- Windsurf

Support means this repo has an adapter strategy and official source references.
It does not mean every client has feature parity. Native skill-folder targets
preserve more behavior; instruction-only targets intentionally block complex
skills unless the user explicitly accepts a lossy conversion.

## Security Model

`Stack Setup Curated` follows a small-registry model for personal/team Agent
Skills bundles.

- **No live external install during sync.** Sync copies from this repo's
  committed `skills/` directory.
- **Repo skills are authoritative.** Installed copies under `.codex\skills` are
  derived and may be overwritten by sync.
- **Hashes are committed.** `skills-lock.json` records file hashes and bundle
  hashes for every bundled skill.
- **Scanner before sync.** `scan_skills.ps1` rejects known-dangerous patterns in
  bundled skills, descriptors, and documentation files that can steer agents.
- **Tamper visibility.** `sync_skills.ps1` reports added, removed, or changed
  installed files before overwrite.
- **Official source authority.** Platform compatibility claims are backed by
  first-party docs in `detected.platformCapabilities[].sourceAuthority`.
- **Source review scorecard.** Install and conversion candidates must carry
  original-source, runtime-surface, permission, conversion-loss, and
  verification evidence before they become durable setup.
- **Unsafe source rejection.** Unofficial directories and mirrors are not
  accepted as adapter authority.
- **Lossy conversion blocks.** `convert_skill.ps1` blocks conversions that would
  drop scripts, assets, MCP servers, hooks, tools, auth, or other
  client-exclusive behavior.

## Verification

Run the full local guard suite before claiming the repo is healthy:

```powershell
& .\scripts\scan_skills.ps1
& .\scripts\harness_test.ps1
& .\skills\stack-setup-audit\scripts\self_test.ps1 -Path (Get-Location)
& .\skills\stack-setup-audit\scripts\fixture_test.ps1
& .\scripts\sync_skills.ps1
git diff --check
```

After intentional skill edits, refresh the lockfile first:

```powershell
& .\scripts\sync_skills.ps1 -UpdateLock
```

## Repository Layout

```text
.
|-- AGENTS.md
|-- CONTRIBUTING.md
|-- LICENSE
|-- README.md
|-- SECURITY.md
|-- skills-lock.json
|-- scripts/
|   |-- scan_skills.ps1
|   |-- harness_test.ps1
|   `-- sync_skills.ps1
`-- skills/
    `-- stack-setup-audit/
```

| Path | Why it matters |
| --- | --- |
| `skills/` | Authoritative source for bundled skills. Edit here first; installed copies are derived. |
| `skills/stack-setup-audit/` | Main audit/conversion skill. Its scripts produce setup recommendations, platform matrices, source-authority checks, and conversion results. |
| `skills-lock.json` | SHA-256 manifest for every bundled skill file. Refresh it only after intentional skill changes. |
| `scripts/scan_skills.ps1` | Static guardrail for bundled skills: prompt-injection phrases, dynamic PowerShell execution, fetch-and-execute patterns, and credential-shaped literals. |
| `scripts/sync_skills.ps1` | Controlled sync from repo skills into the local Codex skills directory, with lock verification and installed-drift reporting. |
| `scripts/harness_test.ps1` | Repo-level regression harness for scanner, lock, sync, and tamper behavior. |
| `AGENTS.md` | Operational instructions for future coding agents working in this repo. |
| `SECURITY.md` | Public security policy and reportable issue categories. |

## Maintainer Workflow

1. Edit files under `skills/` first. Do not edit installed Codex copies as the
   source of truth.
2. For skill changes, run `.\scripts\sync_skills.ps1 -UpdateLock`.
3. Run the full verification suite.
4. Commit only reviewed source files and the refreshed lockfile.
5. Push `main` to `origin` when the worktree is clean.

## External Source Policy

Primary qualified sources are first-party client docs and registries:

- Codex and OpenAI skill sources
- Agent Skills standard
- Anthropic / Claude Code docs and skill references
- GitHub Copilot docs
- Cursor docs
- Google Antigravity docs
- Gemini CLI docs
- OpenCode docs
- Aider docs
- Continue docs
- Cline docs
- Roo Code docs
- Windsurf docs

Community marketplaces and directories are discovery-only. Inspect the original
source project, scripts, permissions, install steps, and provenance before
recommending or copying any skill.

Marketplace and `npx skills` discovery is useful for install mechanics, but it
does not replace platform-native source review. Prefer the target platform's
official ecosystem first. If the capability is missing there, Claude Code and
Codex are good first cross-ecosystem checks, and any other marketplace can be a
source when the skill/plugin only exists there and the original source passes
provenance, license, permission, and runtime-feature review.

## Requirements

- Git
- PowerShell on Windows, or PowerShell 7+ (`pwsh`) elsewhere
- Codex desktop or CLI if you want to sync into a real Codex skill directory

## License And Provenance

This repository is licensed under the MIT License. See `LICENSE`.
