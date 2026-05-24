---
name: codex-setup-audit
description: Use when the user asks for repo onboarding, AI coding assistant setup, cross-client agent configuration, or recommendations for skills, MCP/tools, hooks, commands, agents, automations, rules, permissions, or verification harnesses.
---

# Agent Setup Audit

## Goal

Produce a read-only setup report for a repository that maps agent capabilities to the right client adapters. The audit is capabilities first: context/rules, skills/recipes, MCP/tools, hooks, commands, agents/subagents, automations, permissions, provenance, and verification. Then it maps those capabilities to Codex, Claude Code, GitHub Copilot, Cursor, Google Antigravity, Gemini CLI, OpenCode, Aider, Continue, Cline, Roo Code, Windsurf, or a portable AGENTS.md/Agent Skills baseline.

Baseline reference: Claude Code Setup (`https://claude.com/plugins/claude-code-setup`) analyzes codebases and recommends Claude Code automations across MCP servers, skills, hooks, subagents, and slash commands. This skill must go further than one-client setup by adding safe-source qualification, user-fit discussion, concrete setup plans, model guidance, cross-client adapters, local environment setup, automations, GitHub integration, and avoid-list reasoning.

Vault-derived operating lens: treat skills, MCP servers, hooks, rules, memories, subagents, verifiers, logs, and client-specific config as one agent harness. A setup audit should inspect that harness before recommending new pieces.

## Hard Rules

- Default to read-only. Do not edit repo files, install tools, enable plugins, create hooks, or mutate config unless the user explicitly asks for implementation after the report.
- Separate facts from recommendations. Mark unknowns as unknown.
- Prefer existing client mechanisms over invented ones: context files, rules, skills, MCP/tools, hooks, commands, agents/subagents, automations, permissions, provenance, and local environment setup.
- Do not make Codex the default answer. Start from the capability needed, then map to client adapters and call out unsupported or unverified pieces.
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
   - context surfaces: AGENTS.md, CLAUDE.md, GEMINI.md, `.github/copilot-instructions.md`, `.cursor/rules`, `.windsurf/rules`, `.clinerules`, `.roo/rules`, Continue config, docs, plans, and client-specific instructions
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
  - **Qualified with caveat: Gemini CLI official docs** - `https://google-gemini.github.io/gemini-cli/` and `google-gemini/gemini-cli` docs are authoritative for GEMINI.md, extensions, MCP, commands, hooks, subagents, and agent skills. Verify installed CLI version and extension schema before recommending edits.
  - **Qualified with caveat: OpenCode official docs** - OpenCode docs are authoritative for AGENTS.md rules and `.opencode/agent/` agent configuration. Verify local OpenCode version and project config before assuming behavior.
  - **Qualified with caveat: Aider official docs** - Aider docs are authoritative for conventions files and repo-map behavior. Do not assume native skills, hooks, or MCP parity unless current docs show it.
  - **Qualified with caveat: Continue official docs** - `https://docs.continue.dev/` is authoritative for config.yaml, rules, prompts, tools, context providers, model roles, and MCP servers.
  - **Qualified with caveat: Cline official docs** - `https://docs.cline.bot/` is authoritative for `.clinerules`, workspace workflows under `.clinerules/workflows/`, and MCP tool use in workflows.
  - **Qualified with caveat: Roo Code official docs** - Roo Code docs are authoritative for custom modes, `.roo/rules/`, `.roo/rules-{mode}/`, `.roorules-{mode}`, tool groups, marketplace items, and MCP transports.
  - **Qualified with caveat: Windsurf official docs** - `https://docs.windsurf.com/` is authoritative for Cascade rules, memories, skills, and team-shared `.windsurf/rules/` or AGENTS.md guidance.
  - **Discovery-only: VoltAgent/awesome-agent-skills and awesomeskills.dev** - useful for finding vendor or community leads. Never recommend installation from these directories without inspecting the original repository and pinning provenance.
  - **Rejected as vetted source: officialskills.sh** - do not call it official, trusted, or vetted. Treat any entry found there as an unverified lead only; current public trust signals and third-party maintenance claims are not enough for qualified-source status.
- Prefer first-party vendor repositories and the built-in `skill-installer` curated OpenAI source when available.
- Treat `detected.platformCapabilities[].sourceAuthority` as the machine-readable adapter source registry. Every adapter must point to official or first-party docs; discovery-only directories and unofficial mirrors are never adapter authority.
- Before recommending installation from any discovery-only index, inspect the original GitHub repository, `SKILL.md`, scripts, hooks, install steps, network calls, and permissions.
- Pin external skills to a commit/ref when possible, and record why the repo needs that skill.
- Never recommend installing a skill solely because it is listed in a directory.
- Any marketplace can be a candidate acquisition source when a needed skill or
  plugin only exists there, but the marketplace listing is not enough. Inspect
  the original source, maintainer, license, scripts, install steps, network
  calls, permissions, and pinned version before recommending it.
- When the target platform is missing a capability, check Claude Code and Codex
  ecosystems early because they often have mature skill/plugin coverage, but do
  not stop there if the only good source is another marketplace.

## Native-First Selection Policy

For every target client, search that client's own native ecosystem before
converting anything from another client.

Selection order:

1. Target-native exact match: official marketplace/plugin, native skill, rule,
   command, agent, hook, MCP recipe, or extension for the client the user will
   actually use.
2. Target-native adjacent match: a close equivalent in the same client that can
   be configured without losing safety, provenance, or expected behavior.
3. Cross-platform source: another ecosystem's skill/plugin only when the target
   lacks a native or adjacent option. Check Claude Code and Codex first when
   they are likely to have mature coverage, then inspect any other marketplace
   where the needed skill/plugin exists.
4. Marketplace-only source: allow any marketplace as the source only when the
   needed skill/plugin exists there and the original source passes provenance,
   license, permission, install, and runtime-feature review.
5. Conversion: convert only the smallest feasible artifact and only after
   inspecting source provenance, scripts, permissions, install steps, bundled
   resources, and platform-exclusive features.

Do not make Codex the source of truth for other platforms. Do not make Claude
Code the source of truth either. Use the strongest native ecosystem for the
target platform first, then borrow across ecosystems only to fill a documented
gap. Claude Code and Codex can be first cross-ecosystem checks after a target
gap is proven; they are not exclusive sources.

## Minimal Install Policy

Default to the smallest reviewed install that satisfies the active workflow.

Selection order after a need is confirmed:

1. No install: use existing rules, docs, commands, or built-in tools if they
   already cover the workflow.
2. Single native item: install one target-native skill/plugin/command/rule
   package for the current job.
3. Narrow domain bundle: use a domain-specific bundle instead of a complete
   marketplace pack.
4. Link or convert: prefer a link, source note, or converted instruction
   artifact over installing a risky runtime package when scripts, tools, auth,
   hooks, MCP servers, automations, or agents are not needed.
5. Complete bundle or broad stack: recommend only when the user explicitly
   needs broad coverage, accepts the maintenance cost, and verification covers
   the added surface.

Do not add MCP servers, hooks, automations, agents, background services,
commands, or additional skills just because they look useful. Each installed
piece needs an active workflow, target client, pinned source, safety review,
owner, and verification path. Call out stale, unused, duplicate, or overlapping
setup as bloat to avoid or remove.

## Skill And Plugin Conversion

Use `convert_skill.ps1` only after choosing a target platform. It writes reviewable artifacts into an output directory; it does not install or enable anything by itself.

```powershell
& "$env:USERPROFILE\.codex\skills\codex-setup-audit\scripts\convert_skill.ps1" -SourcePath <skill-or-plugin> -Target github-copilot -OutputPath <out> -Json
```

Conversion rules:

- Conversion is last-resort acquisition. Search the target platform's official
  marketplace/plugins/skills first, then adjacent native equivalents, then other
  platform ecosystems and marketplace-only sources with provenance review.
- Prefer link-only or instruction-only conversion over installing a runtime
  package when supporting scripts, auth, MCP, hooks, agents, tools, or services
  are not required for the active workflow.
- Prefer native Agent Skill folders when the target's official docs support them, such as `.github/skills`, `.cursor/skills`, `.opencode/skills`, `.cline/skills`, or `.windsurf/skills`.
- For targets without a native or close-equivalent skill folder, emit instruction-only artifacts only for simple skills with no bundled resources. Examples: Aider conventions, Continue checks, and Roo rules.
- Block conversions that would drop supporting files, scripts, assets, MCP servers, hooks, tools, auth, or client-exclusive plugin behavior. Use `-AllowPartial` only when the user explicitly accepts a lossy instruction-only artifact after review.
- For plugins, extract skills only from pure skill-bundle plugins. If a plugin includes hooks, MCP config, commands, agents, apps, auth, or unknown root files, report `status: blocked` instead of guessing.
- Include `sourceAuthority` in converter JSON output so downstream tooling can prove the target adapter came from an official source.
- Run `convert_skill.ps1 -ListTargets -Json` to inspect supported targets and whether each target preserves supporting files.

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
- Gemini CLI: map durable guidance to GEMINI.md and package broader behavior as extensions only after checking the current `gemini-extension.json` schema.
- OpenCode: map durable repo guidance to AGENTS.md and specialized agents to `.opencode/agent/` when docs and local version support it.
- Aider: map durable coding conventions to a small conventions file the operator adds to chat; do not claim native skills or hooks without current docs.
- Continue: map context/rules/prompts/tools through config.yaml, context providers, model roles, and MCP servers.
- Cline: map persistent behavior to `.clinerules` and repeatable operator flows to `.clinerules/workflows/*.md`.
- Roo Code: map behavior to `.roo/rules/`, mode-specific `.roo/rules-{mode}/`, custom modes, and MCP/tool groups.
- Windsurf: map team-shared guidance to `.windsurf/rules/` or AGENTS.md and use Cascade skills when behavior needs supporting files.
- Cross-client plans should name which artifacts are portable and which are client-specific. Do not imply one client's hook/rule/plugin format works in another client without documentation evidence.
- For MCP-backed workflows, treat the MCP as the capability and the skill/rule as the recipe for using it: what to open, what evidence to collect, when to stop, and what output to produce.

## Model Guidance

- Fast/cheap model: use for inventory, deterministic script edits, fixture generation, and narrow checks.
- Strong coding model: use for implementation, refactors, test repair, and setup scripts that touch several files.
- Strongest/review model: use for architecture tradeoffs, security-sensitive setup, high-blast-radius automation, and final review.
- Cross-model support: phrase recommendations in capability terms first, then map to the available model family in the user's environment. Do not hard-code one vendor when the repo should support multiple coding assistants safely.
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
