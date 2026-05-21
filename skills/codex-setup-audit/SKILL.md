---
name: codex-setup-audit
description: Use when the user asks for a Claude Code Setup equivalent, repo onboarding audit, or recommendations for Codex plugins, MCP servers, skills, hooks, subagents, commands, automations, or AGENTS.md/rules for a codebase.
---

# Codex Setup Audit

## Goal

Produce a read-only setup report for a repository that matches the Claude Code Setup plugin's job and extends it for Codex: inspect the project and recommend the highest-value agent configuration for this repo.

## Hard Rules

- Default to read-only. Do not edit repo files, install tools, enable plugins, create hooks, or mutate config unless the user explicitly asks for implementation after the report.
- Separate facts from recommendations. Mark unknowns as unknown.
- Prefer existing Codex mechanisms over invented ones: plugins/apps, MCP, skills, hooks, subagents, slash commands, automations, AGENTS.md/rules, GitHub integration, and local environment setup.
- Call out conflicts, duplicate tooling, unstable cache paths, Windows path issues, auth gaps, and security risks.
- Recommend no more than 1-2 high-value items per category unless the user asks for a specific category.
- Keep the final report concise enough to act on.

## Workflow

1. Run the audit helper:

```powershell
& "$env:USERPROFILE\.codex\skills\codex-setup-audit\scripts\audit.ps1" -Path (Get-Location)
```

2. If the user asks for one recommendation type, pass `-Focus` with one of `mcp`, `plugins`, `skills`, `hooks`, `subagents`, `commands`, `automations`, `rules`, or `local`:

```powershell
& "$env:USERPROFILE\.codex\skills\codex-setup-audit\scripts\audit.ps1" -Path (Get-Location) -Focus hooks
```

3. If the user asks for more depth, run the inventory helper and read only the most relevant files it discovers:

```powershell
& "$env:USERPROFILE\.codex\skills\codex-setup-audit\scripts\inventory.ps1" -Path (Get-Location)
```

Usually inspect `README*`, `AGENTS.md`, `CLAUDE.md`, package manifests, workflow files, docs plans, and existing config.

4. Identify the project type, risk profile, common workflows, and bottlenecks.
5. Refine the audit output in this order:
   - `Immediate`: changes or setup that would clearly help now.
   - `Optional`: useful only if the workflow is active.
   - `Avoid`: tempting setup that would add noise, cost, risk, or duplicate existing tools.
6. For every recommendation include:
   - target mechanism: plugin/app, MCP, skill, hook, subagent, command, automation, rule, or local environment
   - reason
   - expected benefit
   - safety notes or prerequisites

## External Skill Discovery

- Use this source index when looking for skills to recommend:
  - **Qualified: OpenAI skills catalog** - `https://github.com/openai/skills`, especially `skills/.system` and `skills/.curated`, is the primary Codex source. `.system` skills are bundled with Codex; `.curated` skills are installable by name through `$skill-installer`.
  - **Qualified: OpenAI skill-installer curated listing** - `$skill-installer` lists from `https://github.com/openai/skills/tree/main/skills/.curated` by default. Prefer it over hand-built lists when recommending Codex skills.
  - **Qualified: Agent Skills standard** - `https://agentskills.io/` and `https://github.com/agentskills/agentskills` are authoritative for format, structure, progressive disclosure, and portability. Use them as specification references, not as a vetted install catalog.
  - **Qualified with caveat: Anthropic skills repository** - `https://github.com/anthropics/skills` is an official upstream reference for Agent Skills patterns and Claude document skills. Treat it as reference material or a candidate source that still needs Codex compatibility review.
  - **Qualified with caveat: GitHub Copilot agent skills docs** - GitHub's official Copilot docs and `gh skill` workflow are useful for cross-agent compatibility and GitHub-hosted skill discovery, but are not a Codex-curated install source.
  - **Qualified with caveat: github/awesome-copilot** - `https://github.com/github/awesome-copilot` is a GitHub-owned community collection referenced by GitHub's agent-skill docs. Treat it as a GitHub ecosystem index, but preview and inspect every skill because GitHub warns these skills are not verified.
  - **Discovery-only: VoltAgent/awesome-agent-skills and awesomeskills.dev** - useful for finding vendor or community leads. Never recommend installation from these directories without inspecting the original repository and pinning provenance.
  - **Rejected as vetted source: officialskills.sh** - do not call it official, trusted, or vetted. Treat any entry found there as an unverified lead only; current public trust signals and third-party maintenance claims are not enough for qualified-source status.
- Prefer first-party vendor repositories and the built-in `skill-installer` curated OpenAI source when available.
- Before recommending installation from any discovery-only index, inspect the original GitHub repository, `SKILL.md`, scripts, hooks, install steps, network calls, and permissions.
- Pin external skills to a commit/ref when possible, and record why the repo needs that skill.
- Never recommend installing a skill solely because it is listed in a directory.

## Report Template

```markdown
**Verdict**
[One short answer: already healthy / needs setup / worth a small setup pass / not worth changing.]

**Detected**
- Stack:
- Repo shape:
- Existing agent setup:
- Gaps:

**Immediate**
- [mechanism] Recommendation - reason and benefit.

**Optional**
- [mechanism] Recommendation - when it becomes useful.

**Avoid**
- [mechanism] What not to add yet - why.

**Next Setup Pass**
1. ...
2. ...
3. ...
```

## Recommendation Heuristics

- Plugin/app: recommend first when Codex already has a curated plugin or connector for the need.
- MCP: recommend only when a stable external system is actively used by the project, such as GitHub, Slack, Linear, Google Drive, databases, logs, or browser automation. Prefer a CLI or built-in tool when it is lower-context and safer.
- Skills: recommend for repeatable judgment-heavy workflows, not one-off instructions. Prefer project-agnostic local skills unless the behavior is specific to one repo.
- Hooks: recommend for cheap, deterministic checks at lifecycle boundaries. Avoid noisy hooks that run slow tests or require network access on every prompt.
- Subagents: recommend for independent investigations, reviews, or disjoint implementation slices. Do not propose subagents for tightly coupled work.
- Slash commands: recommend for short, repeatable operator actions with predictable inputs.
- Automations: recommend only for recurring monitoring, scheduled reports, or follow-ups.
- AGENTS.md/rules: recommend when the repo needs persistent local conventions, architecture boundaries, commands, or safety rules.
- Local environment: recommend when builds need stable setup commands, local server commands, or generated artifacts.

## Red Flags

- Hooks referencing cache paths that change after plugin updates.
- Hooks that depend on shell-specific expansion on Windows.
- Multiple AI tools writing competing config files.
- Secrets in repo, logs, hooks, or command history.
- Broad MCP access where a narrower connector or command would work.
- Long-running or network-heavy checks attached to every user prompt.
- Recommendations that say "install everything" instead of explaining why a repo specifically needs it.
- Skills discovered through third-party indexes without source review, pinned provenance, or a project-specific reason.
