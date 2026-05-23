# Agent Setup Audit

Local project copy of cross-agent setup-audit skills.

## Contents

- `AGENTS.md` - repo-local agent rules for treating this checkout as the skill source of truth.
- `skills-lock.json` - committed SHA-256 manifest for every bundled skill file.
- `skills/codex-setup-audit` - read-only repo setup recommender for AI coding assistants, including context/rules, skills, MCP/tools, hooks, commands, agents, automations, permissions, provenance, and verification.
- `skills/codex-setup-audit/scripts/convert_skill.ps1` - conservative skill/plugin converter for supported clients; writes reviewable artifacts and blocks lossy conversions by default.
- `skills/sourcelift-catalog-refresh` - SourceLift / Great Homes Source catalog-refresh workflow skill.
- `skills/autoresearch` - third-party autonomous metric-loop skill from `uditgoenka/autoresearch`, installed from commit `98398ba5837ce74ca2ba888bc31456f2837cf33c`.

## Install Or Sync

Preferred sync path. This scans the repo skills, verifies `skills-lock.json`,
reports installed-skill drift before overwrite, copies repo skills, verifies
installed hashes, and runs installed setup-audit tests:

```powershell
& .\scripts\sync_skills.ps1
```

After an intentional skill change, refresh the lockfile through the same guarded
path:

```powershell
& .\scripts\sync_skills.ps1 -UpdateLock
```

Manual fallback only for emergency recovery after reviewing the scanner and
lockfile state:

```powershell
Copy-Item -LiteralPath .\skills\codex-setup-audit -Destination "$env:USERPROFILE\.codex\skills" -Recurse -Force
Copy-Item -LiteralPath .\skills\sourcelift-catalog-refresh -Destination "$env:USERPROFILE\.codex\skills" -Recurse -Force
Copy-Item -LiteralPath .\skills\autoresearch -Destination "$env:USERPROFILE\.codex\skills" -Recurse -Force
```

Restart Codex or open a new session after syncing so the skill index refreshes.

## Test

```powershell
& .\scripts\scan_skills.ps1
& .\scripts\harness_test.ps1
& .\skills\codex-setup-audit\scripts\self_test.ps1 -Path (Get-Location)
& .\skills\codex-setup-audit\scripts\fixture_test.ps1
```

## Harness Metrics

- Classification correctness: this repo audits as `Codex skill bundle`; SourceLift fixtures still audit as SourceLift.
- Sync freshness: `sync_skills.ps1` copies all repo skills and verifies installed file hashes.
- Repo integrity: `skills-lock.json` blocks unreviewed source-skill drift unless refreshed with `-UpdateLock`.
- Installed tamper visibility: sync reports added, removed, or changed installed files before replacing them.
- Malicious-content screen: `scan_skills.ps1` blocks direct prompt-injection directives, dynamic PowerShell execution, fetch-and-execute scripts, and credential-shaped secrets.
- Verification coverage: harness, self, and fixture tests exit 0 before claiming the setup is healthy.
- Context separation: audit output labels host Codex hooks/plugins separately from target repo evidence.

## Run

```powershell
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\Shop_Lifter_NG
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\Shop_Lifter_NG -Focus hooks
& .\skills\codex-setup-audit\scripts\convert_skill.ps1 -SourcePath .\skills\codex-setup-audit -Target github-copilot -OutputPath .\out\converted -Json
& .\skills\codex-setup-audit\scripts\convert_skill.ps1 -ListTargets -Json
```

## External Skill Sources

Primary vetted sources are first-party client docs and registries: OpenAI's skills catalog (`https://github.com/openai/skills`) and `$skill-installer`, `agentskills.io` / `agentskills/agentskills`, Anthropic / Claude Code docs, GitHub Copilot docs, Cursor docs, Google Antigravity and Gemini CLI docs, OpenCode docs, Aider docs, Continue docs, Cline docs, Roo Code docs, and Windsurf docs. The audit JSON exposes these as `detected.platformCapabilities[].sourceAuthority` so adapter claims can be checked mechanically.

`convert_skill.ps1` uses those authoritative platform mappings. It preserves full skill folders for targets with native Agent Skill support, emits instruction-only artifacts for simple skills on instruction/rule/check platforms, and blocks plugin or skill conversions that would lose supporting files, hooks, MCP servers, tools, auth, or other client-exclusive behavior.

Treat broad directories such as `VoltAgent/awesome-agent-skills` and `awesomeskills.dev` as discovery-only lead sources. Do not treat `officialskills.sh` as vetted or official; entries found there require original-repo inspection and pinned provenance before any recommendation.
