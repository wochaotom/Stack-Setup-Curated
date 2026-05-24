# Stack Setup Curated

**Source-locked agent setup skills for Codex and adjacent coding agents.**

This repository is a curated skill bundle for setting up, auditing, and safely
porting AI coding-agent workflows. It is not a giant skill marketplace and it is
not an "install everything" script. The niche is narrower: keep a small set of
high-value skills in a reviewed repo, verify their hashes, sync them into Codex,
and make cross-agent setup decisions from official sources instead of guesswork.

```powershell
git clone https://github.com/wochaotom/Stack-Setup-Curated.git
cd Stack-Setup-Curated
& .\scripts\sync_skills.ps1
```

After sync, restart Codex or open a new session so the skill index refreshes.

## What This Gives You

| Capability | What it does |
| --- | --- |
| Curated skill source | Treats `skills/` as the source of truth and installed Codex copies as derived artifacts. |
| Lockfile integrity | Tracks every bundled skill file with SHA-256 hashes in `skills-lock.json`. |
| Tamper-aware sync | Reports installed-skill drift before replacing installed copies. |
| Skill scanning | Blocks obvious prompt-injection phrases, dynamic PowerShell execution, fetch-and-execute patterns, and credential-shaped secrets in bundled skill files. |
| Setup audit | Audits repositories for agent setup fit across rules, skills, MCP/tools, hooks, commands, agents, automations, permissions, provenance, and verification. |
| Safe conversion | Converts simple skills/plugins to supported client layouts when feasible and exits nonzero when conversion would be lossy or unsupported. |

## Included Skills

| Skill | Purpose |
| --- | --- |
| `codex-setup-audit` | Read-only repo setup recommender for AI coding assistants, including cross-client capability mapping and source-authority checks. |
| `sourcelift-catalog-refresh` | SourceLift / Great Homes Source catalog-refresh workflow for catalog cleanup, pricing/provenance review, and export QA. |
| `autoresearch` | Third-party autonomous metric-loop skill from `uditgoenka/autoresearch`, installed from commit `98398ba5837ce74ca2ba888bc31456f2837cf33c`. |

## Quick Start

### Sync Into Codex

```powershell
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
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\SomeRepo
```

Focus one mechanism:

```powershell
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\SomeRepo -Focus hooks
```

Machine-readable output:

```powershell
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\SomeRepo -Json
```

### Convert A Skill

List supported targets:

```powershell
& .\skills\codex-setup-audit\scripts\convert_skill.ps1 -ListTargets -Json
```

Convert a portable skill to GitHub Copilot's skill layout:

```powershell
& .\skills\codex-setup-audit\scripts\convert_skill.ps1 `
  -SourcePath .\skills\codex-setup-audit `
  -Target github-copilot `
  -OutputPath .\out\converted `
  -Json
```

Blocked and unsupported conversions return JSON and exit nonzero, so CI and
automation can fail fast instead of reading a false-success process exit.

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

`Stack Setup Curated` follows a small-registry model similar in spirit to
autoskills, but aimed at a personal/team Codex skill bundle rather than a broad
technology detector.

- **No live third-party install during sync.** Sync copies from this repo's
  committed `skills/` directory.
- **Repo skills are authoritative.** Installed copies under `.codex\skills` are
  derived and may be overwritten by sync.
- **Hashes are committed.** `skills-lock.json` records file hashes and bundle
  hashes for every bundled skill.
- **Scanner before sync.** `scan_skills.ps1` rejects known-dangerous patterns in
  bundled skills.
- **Tamper visibility.** `sync_skills.ps1` reports added, removed, or changed
  installed files before overwrite.
- **Official source authority.** Platform compatibility claims are backed by
  first-party docs in `detected.platformCapabilities[].sourceAuthority`.
- **Unsafe source rejection.** `officialskills.sh` is treated as unverified, and
  unofficial mirrors such as `open-code.ai` are not accepted as adapter
  authority.
- **Lossy conversion blocks.** `convert_skill.ps1` blocks conversions that would
  drop scripts, assets, MCP servers, hooks, tools, auth, or other
  client-exclusive behavior.

## Verification

Run the full local guard suite before claiming the repo is healthy:

```powershell
& .\scripts\scan_skills.ps1
& .\scripts\harness_test.ps1
& .\skills\codex-setup-audit\scripts\self_test.ps1 -Path (Get-Location)
& .\skills\codex-setup-audit\scripts\fixture_test.ps1
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
|-- README.md
|-- skills-lock.json
|-- scripts/
|   |-- scan_skills.ps1
|   |-- harness_test.ps1
|   `-- sync_skills.ps1
`-- skills/
    |-- autoresearch/
    |-- codex-setup-audit/
    `-- sourcelift-catalog-refresh/
```

## Maintainer Workflow

1. Edit files under `skills/` first. Do not edit installed Codex copies as the
   source of truth.
2. For skill changes, run `.\scripts\sync_skills.ps1 -UpdateLock`.
3. Run the full verification suite.
4. Commit only reviewed source files and the refreshed lockfile.
5. Push `main` to `origin` when the worktree is clean.

## Design Benchmarks

This README is intentionally benchmarked against two styles:

- `midudev/autoskills`: short promise, one-command usage, clear security model.
- `Great-Code-Hygiene`: fuller operational docs, install surfaces, maintainer
  checks, and honest verification language.

This repo's intended middle ground is: quick enough to use immediately, explicit
enough that future agents cannot pretend unverified setup is safe.

## External Source Policy

Primary qualified sources are first-party client docs and registries:

- OpenAI skills catalog: `https://github.com/openai/skills`
- Agent Skills standard: `https://agentskills.io/`
- Anthropic / Claude Code docs and skills repository
- GitHub Copilot docs
- Cursor docs
- Google Antigravity docs
- Gemini CLI docs and repository
- OpenCode docs
- Aider docs
- Continue docs
- Cline docs
- Roo Code docs
- Windsurf docs

Broad directories such as `VoltAgent/awesome-agent-skills` and
`awesomeskills.dev` are discovery-only. Inspect original repositories, scripts,
permissions, install steps, and provenance before recommending or copying any
skill.

## Requirements

- Git
- PowerShell on Windows, or PowerShell 7+ (`pwsh`) elsewhere
- Codex desktop or CLI if you want to sync into a real Codex skill directory

## License And Provenance

No repository-wide license has been selected yet. Do not assume an open-source
grant for redistribution until a `LICENSE` file is added by the owner.

The bundled `autoresearch` skill is third-party content from
`uditgoenka/autoresearch` at commit
`98398ba5837ce74ca2ba888bc31456f2837cf33c`. Keep upstream provenance intact
when syncing, modifying, or redistributing bundled skills.
