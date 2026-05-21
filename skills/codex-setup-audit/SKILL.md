---
name: codex-setup-audit
description: Use when the user asks for a Claude Code Setup equivalent, repo onboarding audit, or recommendations for Codex plugins, MCP servers, skills, hooks, subagents, commands, automations, or AGENTS.md/rules for a codebase.
---

# Codex Setup Audit

## Goal

Produce a read-only setup report for a repository that matches the Claude Code Setup plugin's job and extends it for Codex: inspect the project and recommend the highest-value agent configuration for this repo.

Baseline reference: `https://claude.com/plugins/claude-code-setup` analyzes codebases and recommends Claude Code automations across MCP servers, skills, hooks, subagents, and slash commands. This skill must go further for Codex by adding safe-source qualification, user-fit discussion, concrete setup plans, model guidance, AGENTS.md/rules, local environment setup, automations, GitHub integration, Cursor support, Antigravity support, and avoid-list reasoning.

Vault-derived operating lens: treat skills, MCP servers, hooks, rules, memories, subagents, verifiers, logs, and client-specific config as one agent harness. A setup audit should inspect that harness before recommending new pieces.

## Hard Rules

- Default to read-only. Do not edit repo files, install tools, enable plugins, create hooks, or mutate config unless the user explicitly asks for implementation after the report.
- Separate facts from recommendations. Mark unknowns as unknown.
- Prefer existing Codex mechanisms over invented ones: plugins/apps, MCP, skills, hooks, subagents, slash commands, automations, AGENTS.md/rules, GitHub integration, and local environment setup.
- Call out conflicts, duplicate tooling, unstable cache paths, Windows path issues, auth gaps, and security risks.
- Recommend no more than 1-2 high-value items per category unless the user asks for a specific category.
- Keep the final report concise enough to act on.
- Do not treat the first plausible stack as correct. When fit depends on workflow preference, risk tolerance, budget, team process, or model choice, surface a short discussion plan instead of pretending certainty.

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
5. Score fit before recommending tools. Use this checklist:
   - workflow fit: what the repo appears to do and which agent workflows recur
   - evidence fit: files, scripts, docs, CI, configs, or package dependencies supporting the recommendation
   - safety fit: permissions, secrets, network access, generated files, raw inputs, and blast radius
   - maintenance fit: how often the setup will be used and who owns it
   - model fit: cheap/fast model for deterministic checks, stronger coding model for implementation, strongest/review model for architecture, security, or long-running refactors
   - user fit: what must be confirmed with the user before installation or durable config
6. Audit the harness around the model:
   - context surfaces: AGENTS.md, CLAUDE.md, `.cursor/rules`, Antigravity rules, docs, plans, and client-specific instructions
   - tools and MCP: exact tools exposed, owner, auth scope, read/write boundary, logging, and whether a narrower plugin/CLI/script would be safer
   - state and memory: durable files, generated outputs, raw sources, knowledge bases, session logs, and whether state is outside the agent's write authority where needed
   - contracts and verifiers: tests, lint, typecheck, build, visual QA, UAT, schema checks, reviewer checks, and command timing
   - permission gates: human approval before config-mutating, network-heavy, auth, deploy, external-send, raw-data, secret-bearing, or hard-to-reverse actions
   - logs and traces: CI logs, hook logs, MCP/tool call logs, screenshots, diffs, source-health reports, and failure records
   - stop and rollback rules: dirty-worktree handling, branch/worktree policy, retry budget, escalation point, and revert/compensation path
   - review layer: cross-model, reviewer-agent, or fresh-context review for high-blast-radius setup
7. Refine the audit output in this order:
   - `Immediate`: changes or setup that would clearly help now.
   - `Optional`: useful only if the workflow is active.
   - `Avoid`: tempting setup that would add noise, cost, risk, or duplicate existing tools.
8. For every recommendation include:
   - target mechanism: plugin/app, MCP, skill, hook, subagent, command, automation, rule, or local environment
   - reason
   - expected benefit
   - safety notes or prerequisites
   - fit evidence
   - user confirmation needed, if any
9. End with a staged setup plan:
   - `Discuss Before Installing`: 2-4 questions that decide the final stack
   - `Implementation Plan`: ordered implementation steps after the user confirms
   - `Verify Setup`: commands or checks proving the setup works

## External Skill Discovery

- Use this source index when looking for skills to recommend:
  - **Qualified: OpenAI skills catalog** - `https://github.com/openai/skills`, especially `skills/.system` and `skills/.curated`, is the primary Codex source. `.system` skills are bundled with Codex; `.curated` skills are installable by name through `$skill-installer`.
  - **Qualified: OpenAI skill-installer curated listing** - `$skill-installer` lists from `https://github.com/openai/skills/tree/main/skills/.curated` by default. Prefer it over hand-built lists when recommending Codex skills.
  - **Qualified: Agent Skills standard** - `https://agentskills.io/` and `https://github.com/agentskills/agentskills` are authoritative for format, structure, progressive disclosure, and portability. Use them as specification references, not as a vetted install catalog.
  - **Qualified with caveat: Anthropic skills repository** - `https://github.com/anthropics/skills` is an official upstream reference for Agent Skills patterns and Claude document skills. Treat it as reference material or a candidate source that still needs Codex compatibility review.
  - **Qualified with caveat: GitHub Copilot agent skills docs** - GitHub's official Copilot docs and `gh skill` workflow are useful for cross-agent compatibility and GitHub-hosted skill discovery, but are not a Codex-curated install source.
  - **Qualified with caveat: github/awesome-copilot** - `https://github.com/github/awesome-copilot` is a GitHub-owned community collection referenced by GitHub's agent-skill docs. Treat it as a GitHub ecosystem index, but preview and inspect every skill because GitHub warns these skills are not verified.
  - **Qualified with caveat: Cursor official docs** - `https://docs.cursor.com/` is authoritative for Cursor rules, CLI agent, and MCP behavior. Use it for Cursor-compatible plans such as `.cursor/rules` and `mcp.json`; do not treat community Cursor guides as vetted installs.
  - **Qualified with caveat: Google Antigravity official docs** - `https://www.antigravity.google/docs/` is authoritative for Antigravity MCP, permissions, CLI plugins, skills, agents, rules, and hooks. Treat Antigravity plugin plans as client-specific and verify paths such as `~/.gemini/antigravity/` or `~/.gemini/antigravity-cli/` before recommending edits.
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
- Risk profile:
- Model fit:
- Gaps:

**Harness Audit**
- Context:
- Tools/MCP:
- State/memory:
- Contracts/verifiers:
- Permission gates:
- Logs/traces:
- Stop/rollback:
- Review layer:

**Immediate**
- [mechanism] Recommendation - reason and benefit.

**Optional**
- [mechanism] Recommendation - when it becomes useful.

**Avoid**
- [mechanism] What not to add yet - why.

**Model Plan**
1. ...

**Discuss Before Installing**
1. ...

**Implementation Plan**
1. ...
2. ...
3. ...

**Verify Setup**
1. ...
```

## Recommendation Heuristics

- Plugin/app: recommend first when Codex already has a curated plugin or connector for the need.
- MCP: recommend only when a stable external system is actively used by the project, such as GitHub, Slack, Linear, Google Drive, databases, logs, or browser automation. Prefer a CLI or built-in tool when it is lower-context and safer. For shared or config-mutating MCP, require owner, auth scope, read/write boundary, logging, secrets/PII handling, and tool-quality metadata.
- Skills: recommend for repeatable judgment-heavy workflows, not one-off instructions. Prefer project-agnostic local skills unless the behavior is specific to one repo. A good skill is a compact SOP with progressive disclosure, references/scripts for bulky or deterministic work, activation/output checks, and a maintenance path.
- Hooks: recommend for cheap, deterministic checks at lifecycle boundaries. Avoid noisy hooks that run slow tests or require network access on every prompt.
- Subagents: recommend for independent investigations, reviews, or disjoint implementation slices. Do not propose subagents for tightly coupled work.
- Slash commands: recommend for short, repeatable operator actions with predictable inputs.
- Automations: recommend only for recurring monitoring, scheduled reports, or follow-ups.
- AGENTS.md/rules: recommend when the repo needs persistent local conventions, architecture boundaries, commands, or safety rules.
- Local environment: recommend when builds need stable setup commands, local server commands, or generated artifacts.
- Cross-model/reviewer pass: recommend only for security-sensitive setup, high-autonomy automation, external actions, broad MCP/tool exposure, or expensive long-running workflows.

## Client Guidance

- Codex: prefer AGENTS.md/rules, curated plugins/apps, `$skill-installer`, explicit verification commands, and worktree/local environment setup.
- Claude Code: map recommendations to CLAUDE.md, plugins, skills, agents/subagents, hooks, MCP, and slash commands when the user asks for Claude parity.
- GitHub Copilot: map portable Agent Skills and GitHub-hosted skill guidance only after previewing skills because GitHub warns community skills are not verified.
- Cursor: map persistent project guidance to `.cursor/rules`, MCP integration to Cursor's `mcp.json` / `cursor-agent mcp` flow, and avoid copying Codex hooks into Cursor unless Cursor's current docs support the same lifecycle.
- Antigravity: map setup to Antigravity's Agent/Manager workflow, MCP store or `mcp_config.json`, permission controls, and CLI plugin bundles containing skills, agents, rules, MCP servers, and hooks.
- Cross-client plans should name which artifacts are portable and which are client-specific. Do not imply one client's hook/rule/plugin format works in another client without documentation evidence.
- For MCP-backed workflows, treat the MCP as the capability and the skill/rule as the recipe for using it: what to open, what evidence to collect, when to stop, and what output to produce.

## Model Guidance

- Fast/cheap model: use for inventory, deterministic script edits, fixture generation, and narrow checks.
- Strong coding model: use for implementation, refactors, test repair, and setup scripts that touch several files.
- Strongest/review model: use for architecture tradeoffs, security-sensitive setup, high-blast-radius automation, and final review.
- Cross-model support: phrase recommendations in capability terms first, then map to the available model family in the user's environment. Be Codex-first for Codex installs, but do not hard-code one vendor when the user confirms the repo should support Claude Code, GitHub Copilot, Cursor, Antigravity, or another Agent Skills client safely.
- Do not recommend a more expensive or high-autonomy model when a deterministic hook, local command, or smaller model would satisfy the workflow.
- When comparing clients or models, evaluate the whole harness: context assembly, action boundary, verification loop, state persistence, review surface, permission model, and codebase cognition.

## Red Flags

- Hooks referencing cache paths that change after plugin updates.
- Hooks that depend on shell-specific expansion on Windows.
- Multiple AI tools writing competing config files.
- Secrets in repo, logs, hooks, or command history.
- Broad MCP access where a narrower connector or command would work.
- Long-running or network-heavy checks attached to every user prompt.
- MCP servers, terminal hosts, or plugins that auto-register tools/hooks without a config diff and permission review.
- Recommendations that say "install everything" instead of explaining why a repo specifically needs it.
- Skills discovered through third-party indexes without source review, pinned provenance, or a project-specific reason.
- Skills that are prompt dumps, lack negative triggers, lack verification, or promote one project's SPEC into global behavior.
