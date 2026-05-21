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

Primary vetted sources are OpenAI's skills catalog (`https://github.com/openai/skills`) and the built-in `$skill-installer` curated listing. Use `agentskills.io` / `agentskills/agentskills` as the format specification, Anthropic's `anthropics/skills` repository as an upstream reference with compatibility review, and GitHub's Copilot skill docs plus `github/awesome-copilot` as GitHub ecosystem context with per-skill inspection.

Treat broad directories such as `VoltAgent/awesome-agent-skills` and `awesomeskills.dev` as discovery-only lead sources. Do not treat `officialskills.sh` as vetted or official; entries found there require original-repo inspection and pinned provenance before any recommendation.
