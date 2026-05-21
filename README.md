# Codex Setup Audit

Local project copy of the Codex setup-audit skills.

## Contents

- `skills/codex-setup-audit` - read-only repo setup recommender for Codex plugins/apps, MCP, skills, hooks, subagents, commands, automations, rules, and local environment setup.
- `skills/sourcelift-catalog-refresh` - SourceLift / Great Homes Source catalog-refresh workflow skill.
- `skills/autoresearch` - third-party autonomous metric-loop skill from `uditgoenka/autoresearch`, installed from commit `98398ba5837ce74ca2ba888bc31456f2837cf33c`.

## Install Or Sync

Copy skills into the active Codex skills directory:

```powershell
Copy-Item -LiteralPath .\skills\codex-setup-audit -Destination "$env:USERPROFILE\.codex\skills" -Recurse -Force
Copy-Item -LiteralPath .\skills\sourcelift-catalog-refresh -Destination "$env:USERPROFILE\.codex\skills" -Recurse -Force
Copy-Item -LiteralPath .\skills\autoresearch -Destination "$env:USERPROFILE\.codex\skills" -Recurse -Force
```

Restart Codex or open a new session after syncing so the skill index refreshes.

## Test

```powershell
& .\skills\codex-setup-audit\scripts\self_test.ps1 -Path D:\Projects\Shop_Lifter_NG
& .\skills\codex-setup-audit\scripts\fixture_test.ps1
```

## Run

```powershell
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\Shop_Lifter_NG
& .\skills\codex-setup-audit\scripts\audit.ps1 -Path D:\Projects\Shop_Lifter_NG -Focus hooks
```

## External Skill Sources

Use `officialskills.sh` and `VoltAgent/awesome-agent-skills` as discovery indexes only. Before installing anything found there, inspect the original GitHub repo, `SKILL.md`, scripts, hooks, install steps, network calls, and permissions. Prefer first-party vendor repos and pin external skills to a commit/ref when possible.
