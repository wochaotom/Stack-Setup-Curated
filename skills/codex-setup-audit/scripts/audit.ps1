param(
    [string]$Path = (Get-Location).Path,
    [ValidateSet("all", "mcp", "plugins", "skills", "hooks", "subagents", "commands", "automations", "rules", "local")]
    [string]$Focus = "all",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inventoryPath = Join-Path $scriptDir "inventory.ps1"
$inventory = & $inventoryPath -Path $Path | ConvertFrom-Json
$root = $inventory.root

function Read-Text($LiteralPath, $MaxChars = 40000) {
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return "" }
    $text = Get-Content -LiteralPath $LiteralPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { return "" }
    if ($text.Length -gt $MaxChars) { return $text.Substring(0, $MaxChars) }
    return $text
}

function Add-Rec($Bucket, $Mechanism, $Title, $Reason, $Benefit, $Safety = "", $FitEvidence = "", $Confirmation = "") {
    if (-not $FitEvidence) { $FitEvidence = Get-DefaultFitEvidence $Mechanism }
    $script:recommendations[$Bucket] += [ordered]@{
        mechanism = $Mechanism
        title = $Title
        reason = $Reason
        benefit = $Benefit
        safety = $Safety
        fitEvidence = $FitEvidence
        confirmation = $Confirmation
    }
}

function Get-RiskProfile() {
    $risks = @()
    if ($signals.hasDirtyWorktree) { $risks += "dirty worktree" }
    if ($signals.hasExcelInputs -or $signals.looksLikeSourceLift) { $risks += "raw/generated data boundary" }
    if ($signals.codexHooksEnabled -or $signals.codexPluginHooksEnabled) { $risks += "host hook/plugin execution" }
    if (-not $signals.hasTests) { $risks += "weak mechanical verification" }
    if ($signals.hasCi) { $risks += "CI/release surface" }
    if ($risks.Count -eq 0) { return "low: lightweight repo with no major automation or data-risk signals detected" }
    $level = if ($risks.Count -ge 3) { "elevated" } else { "moderate" }
    return "${level}: " + ($risks -join ", ")
}

function Get-ModelFit() {
    if ($signals.looksLikeSourceLift) {
        return "tiered: fast inventory, strong catalog implementation, review-grade pricing/provenance decisions"
    }
    if ($signals.hasFrontendDeps -or $signals.hasBackendDeps -or $signals.hasTypeScript) {
        return "tiered: fast checks, strong implementation, review-grade architecture/security"
    }
    return "minimal: fast inventory first, escalate only for durable setup changes"
}

function Get-ModelPlan() {
    if ($signals.looksLikeSourceLift) {
        return @(
            "Fast model: inventory supplier files, count missing images/prices, and run deterministic smoke checks.",
            "Strong coding model: update catalog generation logic, workbook export code, or local UI behavior.",
            "Strongest/review model: review pricing policy, provenance rules, raw-data edit policy, or broad automation plans."
        )
    }
    return @(
        "Fast model: inventory files, run lint/test checks, and make narrow deterministic edits.",
        "Strong coding model: implement setup scripts, project rules, tests, or refactors across several files.",
        "Strongest/review model: review security, architecture, high-autonomy hooks, MCP access, or long-running migrations."
    )
}

function Get-SafeSourcePolicy() {
    return @(
        "Use a native-first selection order: target platform marketplace/plugin/skill first, adjacent target-native equivalent second, cross-ecosystem acquisition and conversion last.",
        "If the target lacks a capability, check Claude Code and Codex ecosystems early when relevant, then allow any other marketplace as a source only when the needed skill/plugin exists there and passes source review.",
        "Prefer first-party client docs and registries for each target adapter instead of assuming one client's artifact format works everywhere.",
        "Use Agent Skills, OpenAI, Anthropic, GitHub Copilot, Cursor, Google Antigravity/Gemini CLI, OpenCode, Aider, Continue, Cline, Roo Code, and Windsurf official docs as compatibility sources with review.",
        "Treat broad community directories as discovery-only and inspect original repos before recommending.",
        'Reject `officialskills.sh` as a vetted source.'
    )
}

function Get-NativeFirstSelectionPolicy() {
    return @(
        "1. Target-native exact match: search the chosen client's official marketplace, built-in plugins, native skills, rules, commands, agents, hooks, MCP docs, and extension model.",
        "2. Target-native adjacent match: prefer a close same-client equivalent when it preserves the behavior safely.",
        "3. Cross-ecosystem source: after native and adjacent target options are missing, check Claude Code and Codex first when they are likely to have mature coverage, then inspect any other marketplace where the needed skill/plugin exists.",
        "4. Marketplace-only source: allow any marketplace as a source only after reviewing the original repository, maintainer, license, scripts, install steps, network calls, permissions, and pinned version.",
        "5. Conversion: convert the smallest feasible artifact and block conversion when scripts, assets, MCP servers, hooks, auth, tools, agents, apps, or client-exclusive behavior would be lost."
    )
}

function Get-MinimalInstallPolicy() {
    return @(
        "Default to no install until a concrete active workflow, target client, pinned source, safety review, owner, and verification path exist.",
        "Install one native skill/plugin/command/rule package for the current job; do not install a broad stack by default.",
        "Prefer narrow domain bundles over complete marketplace bundles.",
        "Prefer link-only guidance or instruction-only conversion over installing risky runtime packages when scripts, tools, auth, hooks, MCP servers, automations, agents, or background services are not needed.",
        "Treat stale, unused, duplicate, overlapping, or speculative setup as bloat to avoid or remove."
    )
}

function Get-ClientPlan() {
    return @(
        "Start from capabilities first: context/rules, skills, MCP/tools, hooks, commands, agents, automations, permissions, provenance, and verification.",
        "Map those capabilities through client adapters instead of making Codex, Claude Code, Cursor, or any other client the default answer.",
        "For each target client, search native plugins, skills, marketplaces, rules, commands, agents, hooks, and MCP recipes before considering another platform's skill.",
        "Use cross-ecosystem conversion only when the target platform lacks a native or adjacent capability; check Claude Code and Codex early when relevant, but allow any sole-source marketplace after provenance review.",
        "Prefer portable artifacts such as AGENTS.md and Agent Skills when they fit; use client-specific files only where the client's docs back the behavior.",
        "Examples: Cursor uses `.cursor/rules`; Antigravity: use MCP config, permissions, hooks, and agents only through documented Antigravity/Gemini mechanisms.",
        "Treat unsupported capabilities as explicit gaps with verification notes, not as silent promises."
    )
}

function New-SourceAuthority($Sources, $Notes = "") {
    return [ordered]@{
        status = "official"
        sources = @($Sources)
        notes = $Notes
    }
}

function Get-PlatformSourceAuthority($Client) {
    switch ($Client) {
        "Codex" {
            return New-SourceAuthority @(
                "https://github.com/openai/skills",
                "https://agentskills.io/"
            ) "OpenAI skills catalog and the Agent Skills standard are the source references for Codex skill bundles."
        }
        "Claude Code" {
            return New-SourceAuthority @(
                "https://docs.claude.com/en/docs/claude-code",
                "https://github.com/anthropics/skills",
                "https://agentskills.io/"
            ) "Claude Code docs plus Anthropic's Agent Skills repository are authoritative for Claude-specific adapters."
        }
        "GitHub Copilot" {
            return New-SourceAuthority @(
                "https://docs.github.com/en/copilot"
            ) "GitHub Docs are authoritative; community skill directories still require per-skill inspection."
        }
        "Cursor" {
            return New-SourceAuthority @(
                "https://cursor.com/docs"
            ) "Cursor's own docs are authoritative for rules, MCP, CLI, and skills support."
        }
        "Google Antigravity" {
            return New-SourceAuthority @(
                "https://www.antigravity.google/docs/home",
                "https://www.antigravity.google/docs/plugins",
                "https://www.antigravity.google/docs/hooks"
            ) "Google Antigravity docs are authoritative for skills, plugins, hooks, MCP, permissions, and agents."
        }
        "Gemini CLI" {
            return New-SourceAuthority @(
                "https://google-gemini.github.io/gemini-cli/docs/",
                "https://github.com/google-gemini/gemini-cli"
            ) "Gemini CLI docs and repository are authoritative for extensions, commands, MCP, hooks, and skills."
        }
        "OpenCode" {
            return New-SourceAuthority @(
                "https://opencode.ai/docs/"
            ) "Use opencode.ai official docs; do not rely on unofficial mirrors."
        }
        "Aider" {
            return New-SourceAuthority @(
                "https://aider.chat/docs/"
            ) "Aider's official docs are authoritative for conventions, repo-map behavior, and CLI configuration."
        }
        "Continue" {
            return New-SourceAuthority @(
                "https://docs.continue.dev/"
            ) "Continue docs are authoritative for checks, config, rules, prompts, tools, context providers, and MCP."
        }
        "Cline" {
            return New-SourceAuthority @(
                "https://docs.cline.bot/"
            ) "Cline docs are authoritative for rules, skills, plugins, workflows, MCP, hooks, scheduling, and subagents."
        }
        "Roo Code" {
            return New-SourceAuthority @(
                "https://docs.roocode.com/"
            ) "Roo Code docs remain the official source; note the current project status before recommending new setup."
        }
        "Windsurf" {
            return New-SourceAuthority @(
                "https://docs.windsurf.com/"
            ) "Windsurf docs are authoritative for Cascade rules, memories, skills, and plugins."
        }
        default {
            return New-SourceAuthority @() "No source authority registered for this client."
        }
    }
}

function New-PlatformCapability($Client, $Confidence, $Docs, $Context, $Skills, $Mcp, $Hooks, $Commands, $Agents, $Automations, $Permissions, $Provenance, $Verification) {
    return [ordered]@{
        client = $Client
        confidence = $Confidence
        docs = @($Docs)
        sourceAuthority = Get-PlatformSourceAuthority $Client
        capabilities = [ordered]@{
            context = $Context
            skills = $Skills
            mcp = $Mcp
            hooks = $Hooks
            commands = $Commands
            agents = $Agents
            automations = $Automations
            permissions = $Permissions
            provenance = $Provenance
        }
        verification = $Verification
    }
}

function Get-PlatformCapabilityMatrix() {
    return @(
        New-PlatformCapability "Codex" "docs-backed" @("local Codex skill/plugin model", "AGENTS.md convention") `
            "AGENTS.md plus skill metadata; keep host Codex config separate from target repo evidence." `
            "SKILL.md bundles under skills/ or installed skill directories." `
            "MCP/plugins/apps when exposed by Codex; prefer narrow connectors over broad servers." `
            "Codex hooks/plugin hooks where enabled; avoid unstable plugin-cache paths." `
            "Built-in slash commands and skill entrypoints; custom command support is not assumed." `
            "Subagents/reviewer agents through available client tooling." `
            "Codex app automations for recurring work only after owner/cadence is confirmed." `
            "Sandbox, approval policy, and plugin permissions must be reported before recommending mutations." `
            "skills-lock.json, source commit pins, sync hashes, and tamper reports." `
            "Run sync, scan, harness, and the repo's own verification commands."

        New-PlatformCapability "Claude Code" "docs-backed" @("Claude Code docs: CLAUDE.md, skills, hooks, MCP, slash commands, subagents") `
            "CLAUDE.md project memory and scoped memory files." `
            "Agent Skills/Claude skills with SKILL.md and progressive disclosure." `
            "MCP servers through Claude Code configuration." `
            "Lifecycle hooks for deterministic external checks." `
            ".claude/commands/*.md and MCP prompts exposed as slash commands." `
            "Subagents/agents for isolated review or task execution." `
            "No generic scheduler assumed; use external CI or an explicit client feature if present." `
            "Tool permissions and hook side effects need review before enabling." `
            "Pin external skills/plugins and record install source." `
            "Use /context, /hooks, MCP listing, and a small task run to confirm loading."

        New-PlatformCapability "GitHub Copilot" "docs-backed" @("GitHub Docs: repository custom instructions and AGENTS.md") `
            ".github/copilot-instructions.md, .github/instructions/*.instructions.md, AGENTS.md, and root CLAUDE.md/GEMINI.md where supported." `
            "GitHub-hosted/Agent Skills only after previewing; community skills are not automatically verified." `
            "MCP support depends on the Copilot surface and host; do not assume parity with local IDE clients." `
            "No repo hook system; use GitHub Actions or local client hooks instead." `
            "Prompt files and instruction files, not guaranteed slash-command parity." `
            "Copilot coding agent/custom agents where enabled by the GitHub/IDE plan." `
            "GitHub Actions or issue/PR workflows are the durable automation layer." `
            "Repository permissions, Actions secrets, and PR write access are the main gates." `
            "Commit instruction files and pin any external skill source." `
            "Check Copilot references show the instruction file and run a representative Copilot task."

        New-PlatformCapability "Cursor" "docs-backed" @("Cursor docs: rules and MCP") `
            ".cursor/rules for persistent project guidance." `
            "No portable Agent Skills assumption; route skills through rules or MCP-backed recipes." `
            "Cursor MCP via mcp.json / cursor-agent mcp flow." `
            "Do not copy Codex/Claude hook syntax unless Cursor docs support the lifecycle." `
            "Cursor commands are client-specific; keep reusable workflows in docs or rules." `
            "Agent behavior is mode/client-driven; no permanent subagent artifact assumed by default." `
            "Use CI/schedulers outside Cursor for recurring work." `
            "Review MCP permissions and write scopes." `
            "Track .cursor/rules and mcp.json changes in git." `
            "Open Cursor rule UI or run a small task that should cite the rule."

        New-PlatformCapability "Google Antigravity" "docs-backed" @("Antigravity docs: MCP, hooks, agents, permissions") `
            ".agents/ workspace customization and Antigravity/Gemini rules where documented." `
            "Antigravity skills or CLI plugin bundles when the docs support the target artifact." `
            "~/.gemini/antigravity/mcp_config.json or MCP store configuration." `
            "hooks.json with PreToolUse, PostToolUse, PreInvocation, PostInvocation, and Stop handlers." `
            "Client/plugin commands only where documented by the Antigravity bundle." `
            "Agents with system_prompt and tool-enable flags." `
            "Use external scheduler unless Antigravity workspace has an explicit automation feature." `
            "Permission controls, write tools, MCP tools, and subagent tools must be explicit." `
            "Pin plugin bundles and review config diffs before enabling." `
            "Inspect Antigravity settings/config and run a small agent task using the target rule/tool."

        New-PlatformCapability "Gemini CLI" "docs-backed" @("Gemini CLI docs: GEMINI.md, extensions, MCP, commands, hooks, skills") `
            "GEMINI.md plus project .gemini settings where appropriate." `
            "Gemini CLI extensions can bundle prompts, MCP servers, commands, hooks, subagents, and agent skills." `
            "settings.json mcpServers or `gemini mcp add` for stdio MCP servers." `
            "Hooks through Gemini CLI extension/config where documented." `
            "Custom commands through extensions." `
            "Subagents through extension support where available." `
            "Use external scheduler or explicit extension workflow; do not assume daemon behavior." `
            "Review extension config, MCP server commands, and write scopes." `
            "Pin extension source and generated gemini-extension.json." `
            "Run `gemini extensions list`, MCP listing, and a small task that reads GEMINI.md."

        New-PlatformCapability "OpenCode" "docs-backed" @("OpenCode docs: AGENTS.md rules and .opencode/agent") `
            "AGENTS.md project guidelines." `
            "Agents under .opencode/agent/ or user config where documented." `
            "MCP support should be verified from OpenCode config before recommending." `
            "No generic hook parity assumed." `
            "OpenCode commands/client operations only where documented." `
            ".opencode/agent markdown configs for specialized agents." `
            "Use external scheduler/CI for recurring checks." `
            "Check project config and agent write boundaries." `
            "Pin agent files and track .opencode diffs." `
            "Run /init or a small OpenCode task and confirm AGENTS.md/agent config is read."

        New-PlatformCapability "Aider" "docs-backed" @("Aider docs: coding conventions and repo map") `
            "CONVENTIONS.md or similar guidance files added to the chat; repo map supplies structure context." `
            "No native Agent Skills assumption; use concise convention docs and commands." `
            "No first-class MCP adapter assumed by this audit." `
            "No hook lifecycle assumed; use git/pre-commit/CI outside Aider." `
            "Aider CLI commands and chat workflows." `
            "No persistent subagent artifact assumed." `
            "Use shell/CI scheduler outside Aider." `
            "Git commit mode, file allowlist, and command execution need operator review." `
            "Commit convention files and record CLI flags/config." `
            "Start Aider with the convention file and verify it follows one concrete rule."

        New-PlatformCapability "Continue" "docs-backed" @("Continue docs: config.yaml, rules, prompts, tools, context providers, MCP") `
            "config.yaml rules or Markdown rules for Agent/Chat/Edit behavior." `
            "No direct SKILL.md parity assumed; model recipes as prompts/rules/tools." `
            "mcpServers plus MCP context provider." `
            "No lifecycle hooks assumed; use tools or external checks." `
            "Prompt templates and slash commands in Continue config." `
            "Custom agents/model roles through Continue configuration." `
            "Use CI/external scheduler for recurring work." `
            "Review tool definitions, context providers, and model/provider permissions." `
            "Version config.yaml and any prompt/rule files." `
            "Use @ context providers and a representative edit task to confirm rule loading."

        New-PlatformCapability "Cline" "docs-backed" @("Cline docs: .clinerules, workflows, MCP") `
            ".clinerules project rules." `
            "No SKILL.md parity assumed; use rules and workflow markdown." `
            "MCP tools can be referenced in workflows." `
            "No general hook lifecycle assumed in this matrix." `
            ".clinerules/workflows/*.md invoked as slash workflows." `
            "Plan/Act behavior and workflows, not permanent subagent files by default." `
            "Use workflows for on-demand tasks; external scheduler for recurring tasks." `
            "Workflows execute with user permissions; review external workflows before running." `
            "Commit .clinerules and workflow files." `
            "Invoke one workflow and confirm it stops on test failure as specified."

        New-PlatformCapability "Roo Code" "docs-backed" @("Roo Code docs: custom modes, rules, MCP") `
            ".roo/rules/ and .roo/rules-{mode}/, with .roorules-{mode} fallback where documented." `
            "No direct SKILL.md parity assumed; use mode rules and marketplace items with review." `
            "MCP transports and marketplace MCPs where configured." `
            "No generic hook lifecycle assumed." `
            "Mode-specific workflows through custom modes/rules." `
            "Custom modes with tool groups such as read, edit, command, and mcp." `
            "Use external scheduler unless a Roo workflow explicitly supports recurrence." `
            "Tool groups are the main permission boundary and must be narrow." `
            "Commit .roo rule files and exported mode config when project-specific." `
            "Switch to the mode and run a small task that should load the mode rules."

        New-PlatformCapability "Windsurf" "docs-backed" @("Windsurf docs: rules, skills, memories") `
            ".windsurf/rules/ and AGENTS.md for durable team-shared guidance." `
            "Cascade skills when the behavior should be picked up automatically and needs supporting files." `
            "MCP support depends on Windsurf/Cascade configuration; verify exact server config before recommending." `
            "No hook parity assumed unless current Windsurf docs expose the lifecycle." `
            "Workflows/skills as documented by Cascade." `
            "Cascade modes/agents where available; do not assume Claude/Codex subagent format." `
            "Use external scheduler for recurring checks." `
            "Review tool permissions and memory/rule write behavior." `
            "Commit .windsurf/rules and skill folders; avoid opaque memory-only setup for team rules." `
            "Use Cascade customization UI or a task that should cite the rule/skill."
    )
}

function Get-HarnessAudit() {
    $context = "Context: check AGENTS.md, CLAUDE.md, GEMINI.md, .github/copilot-instructions.md, .cursor/rules, .windsurf/rules, .clinerules, .roo/rules, Continue config, and client-specific instructions; keep always-loaded guidance as a router to deeper docs."
    if (-not (Test-Path -LiteralPath (Join-Path $root "AGENTS.md"))) {
        $context += " Gap: no AGENTS.md detected."
    }

    $tools = "Tools/MCP: prefer narrow plugins, CLIs, or scripts; for MCP require owner, auth scope, read/write boundary, logging, secrets/PII handling, and tool-quality metadata."
    if ($signals.codexHooksEnabled -or $signals.codexPluginHooksEnabled) {
        $tools += " Existing hook/plugin-hook config needs cache-path and side-effect review."
    }

    $state = "State/memory: preserve raw/generated boundaries, keep durable plans/logs path-addressable, and avoid adding memory systems without an active workflow."
    if ($signals.looksLikeSourceLift) {
        $state += " Catalog raw inputs should stay read-only unless explicitly approved."
    }

    $contracts = "Contracts/verifiers: require at least one cheap deterministic verification command before promoting hooks, automations, or background work."
    if (-not $signals.hasTests) {
        $contracts += " Gap: no tests detected."
    }

    return @(
        $context,
        $tools,
        $state,
        $contracts,
        "Permission gates: human-gate config-mutating, network-heavy, auth, deploy, external-send, raw-data, secret-bearing, and hard-to-reverse actions.",
        "Logs/traces: keep diffs, command output, CI/hook logs, screenshots, MCP/tool-call logs, and source-health reports inspectable after the run.",
        "Stop/rollback: define dirty-worktree handling, branch/worktree policy, retry budget, escalation point, and revert or compensation path.",
        "Review layer: use cross-model/reviewer or fresh-context review for high-blast-radius setup, broad MCP exposure, security-sensitive changes, or long-running automation."
    )
}

function Get-DiscussionQuestions() {
    $questions = @()
    $questions += "Which AI clients should this repo actually support: Codex, Claude Code, GitHub Copilot, Cursor, Antigravity, Gemini CLI, OpenCode, Aider, Continue, Cline, Roo Code, Windsurf, or a portable AGENTS.md/Agent Skills baseline?"
    $questions += "For each chosen client, which native marketplace/plugin/skill source should be checked first, and which cross-ecosystem marketplaces are acceptable if the skill/plugin only exists there?"
    $questions += "What is the smallest install that satisfies the active workflow, and can any requested complete bundle be replaced by a narrow domain bundle, link, or conversion?"
    if ($signals.looksLikeSourceLift) {
        $questions += "Should catalog refreshes remain manual, or is there a real supplier cadence that justifies automation?"
        $questions += "Who is allowed to approve edits to raw source files versus generated catalog outputs?"
    } else {
        $questions += "Which workflow hurts most today: onboarding, review, CI repair, docs, security, frontend QA, or release prep?"
        $questions += "How much autonomy is acceptable: read-only recommendations, proposed patches, or scheduled/background work?"
    }
    $questions += "Should setup optimize for cost/speed, strongest review quality, or a tiered model plan, and which action classes need explicit approval gates?"
    return $questions
}

function Get-SetupPlan() {
    if ($signals.looksLikeSourceLift) {
        $skillStep = if ($signals.hasSourceLiftSkill) {
            'Use `$sourcelift-catalog-refresh` for future catalog refresh, workbook QA, pricing review, and UI proof work.'
        } else {
            "Create a SourceLift-specific catalog-refresh skill only if this workflow will repeat."
        }
        return @(
            "Confirm the discussion answers, especially target AI clients, autonomy level, and model budget.",
            "Search each target client's native ecosystem first, then check Claude Code, Codex, and any sole-source marketplace only after documenting the missing capability.",
            "Choose the smallest reviewed install: no install, one native item, a narrow domain bundle, or link/convert before any complete bundle.",
            "Write or update AGENTS.md/rules with source-catalog boundaries, verification commands, and raw/generated file policy.",
            $skillStep,
            "Run the catalog build, JSON/workbook checks, and one UI smoke workflow before adding hooks or automations."
        )
    }
    return @(
        "Confirm the discussion answers, especially target AI clients, autonomy level, and model budget.",
        "Search each target client's native ecosystem first, then check Claude Code, Codex, and any sole-source marketplace only after documenting the missing capability.",
        "Choose the smallest reviewed install: no install, one native item, a narrow domain bundle, or link/convert before any complete bundle.",
        "Write or update AGENTS.md/rules with repo-specific boundaries and verification commands.",
        "Install or enable only the confirmed high-fit plugin/app/skill items, preferring vetted sources and explicit user approval.",
        "Run the listed verification commands and one representative workflow before adding hooks or automations."
    )
}

function Get-VerifyPlan() {
    $verify = @()
    if ($signals.looksLikeSourceLift) {
        $verify += "Run the catalog build command from the repo README or project rules."
        $verify += "Check generated catalog JSON and workbook outputs exist and parse cleanly."
        $verify += "Run one local UI smoke check if catalog UI files changed."
    } elseif ($signals.hasNodeTests) {
        $verify += "Run the package test script and any detected typecheck/lint script."
    } elseif ($signals.hasPythonQuality) {
        $verify += "Run pytest and any configured Ruff/mypy/pyright checks."
    } else {
        $verify += "Run `git status --short` and inspect setup-only file changes."
        $verify += "Define a minimal repo verification command before implementing durable setup."
    }
    $verify += 'Re-run `audit.ps1 -Json` and confirm selected recommendations, discussion questions, and avoid-list entries still match the repo.'
    $verify += "Run one high-risk setup through cross-model/reviewer or fresh-context review before enabling broad MCP, hooks, or scheduled automation."
    return $verify
}

function Get-DefaultFitEvidence($Mechanism) {
    $evidence = switch ($Mechanism) {
        "AGENTS.md/rules" {
            @("No AGENTS.md detected", "repo has persistent source/workflow rules worth preserving")
        }
        "rule" {
            @("dirty worktree detected", "repo setup changes need isolation from user work")
        }
        "skill" {
            @("repeatable domain workflow detected", "matching installed/local skill available or justified")
        }
        "local environment" {
            @("no tests detected", "agents need a stable command before hooks or automation")
        }
        "command" {
            @("repeatable operator workflow detected", "built-in commands avoid custom command maintenance")
        }
        "automation" {
            @("recurring value depends on real cadence", "source-health workflow is useful only after pilots")
        }
        "hook" {
            @("hook/plugin-hook config or hook-sensitive workflow detected", "recommendation is bounded by speed and side-effect risk")
        }
        "MCP" {
            @("external-system signal is weak or unconfirmed", "narrower built-in plugin/app is safer until daily workflow proves need")
        }
        "subagent" {
            @("repo size and task coupling drive delegation fit", "small repos usually do not need permanent reviewer agents")
        }
        "plugin/app" {
            @("curated connector/plugin is available for detected workflow", "preferred over broad MCP when scope is narrow")
        }
        default {
            @("repo inventory matched $Mechanism recommendation heuristics")
        }
    }
    if ($signals.looksLikeSourceLift) { $evidence += "SourceLift/Great Homes Source text plus catalog structure detected" }
    if ($signals.hasLocalSkillBundle) { $evidence += "local Agent Skills bundle detected under skills/" }
    if ($signals.hasFrontendDeps) { $evidence += "frontend dependencies detected" }
    if ($signals.hasBackendDeps) { $evidence += "backend dependencies detected" }
    if ($signals.hasTypeScript) { $evidence += "TypeScript detected" }
    if ($signals.codexHooksEnabled -or $signals.codexPluginHooksEnabled) { $evidence += "existing hook/plugin-hook config detected" }
    return "Mechanism: $Mechanism. Signals: " + (($evidence | Select-Object -Unique) -join "; ")
}

function Test-FocusMatch($Recommendation) {
    if ($Focus -eq "all") { return $true }
    $mechanism = [string]$Recommendation.mechanism
    switch ($Focus) {
        "mcp" { return $mechanism -eq "MCP" }
        "plugins" { return $mechanism -eq "plugin/app" }
        "skills" { return $mechanism -eq "skill" }
        "hooks" { return $mechanism -eq "hook" }
        "subagents" { return $mechanism -eq "subagent" }
        "commands" { return $mechanism -eq "command" }
        "automations" { return $mechanism -eq "automation" }
        "rules" { return $mechanism -eq "AGENTS.md/rules" -or $mechanism -eq "rule" }
        "local" { return $mechanism -eq "local environment" }
        default { return $true }
    }
}

function Has-File($RelativePath) {
    return [bool]($inventory.importantFiles + $inventory.ciFiles + $inventory.testFiles + $inventory.docsFiles | Where-Object { $_ -ieq $RelativePath })
}

$readme = Read-Text (Join-Path $root "README.md")
$packageText = Read-Text (Join-Path $root "package.json")
$pyprojectText = Read-Text (Join-Path $root "pyproject.toml")
$plans = ""
foreach ($doc in @($inventory.docsFiles | Select-Object -First 12)) {
    $plans += "`n" + (Read-Text (Join-Path $root $doc) 12000)
}
$allText = ($readme + "`n" + $plans)
$package = $null
if ($packageText.Trim().Length -gt 0) {
    try { $package = $packageText | ConvertFrom-Json } catch { $package = $null }
}

$localSkillFiles = @()
if (Test-Path -LiteralPath (Join-Path $root "skills")) {
    $localSkillFiles = @(Get-ChildItem -LiteralPath (Join-Path $root "skills") -Recurse -File -Filter "SKILL.md" -ErrorAction SilentlyContinue)
}
$hasLocalSkillBundle = $localSkillFiles.Count -gt 0
$hasStaticApp = Test-Path -LiteralPath (Join-Path $root "app\index.html")
$hasCatalogBuilder = Test-Path -LiteralPath (Join-Path $root "scripts\build_catalog.py")
$hasExcelInputs = [bool]((Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.xlsx" -ErrorAction SilentlyContinue | Select-Object -First 1))
$hasCatalogData = (Test-Path -LiteralPath (Join-Path $root "app\data\catalog.json")) -or (Test-Path -LiteralPath (Join-Path $root "outputs\great_homes_source_catalog.xlsx"))
$hasSourceLiftPlan = Test-Path -LiteralPath (Join-Path $root "_knowledge_base\plan-source-price-platform-v5-20260510.md")
$sourceLiftTextSignal = $allText -match "SourceLift|Great Homes Source|Moorizon|source catalog|line sheet|quote-ready"
$sourceLiftStructuralSignal = $hasCatalogBuilder -or $hasExcelInputs -or $hasCatalogData -or $hasSourceLiftPlan

$depNames = @()
$scriptNames = @()
if ($package) {
    foreach ($section in @("dependencies", "devDependencies", "peerDependencies", "optionalDependencies")) {
        if ($package.PSObject.Properties.Name -contains $section -and $package.$section) {
            $depNames += @($package.$section.PSObject.Properties.Name)
        }
    }
    if ($package.PSObject.Properties.Name -contains "scripts" -and $package.scripts) {
        $scriptNames = @($package.scripts.PSObject.Properties.Name)
    }
}

$signals = [ordered]@{
    isGitHub = [bool](@($inventory.git.remotes) -match "github\.com")
    isSmallRepo = [int]$inventory.counts.filesSampled -lt 100
    hasDirtyWorktree = [bool](@($inventory.git.statusShort) | Where-Object { $_ -match "^( M|M |A |D |\?\?)" })
    hasLocalSkillBundle = $hasLocalSkillBundle
    hasStaticApp = $hasStaticApp
    hasCatalogBuilder = $hasCatalogBuilder
    hasExcelInputs = $hasExcelInputs
    hasTests = [bool](@($inventory.testFiles).Count -gt 0)
    hasCi = [bool](@($inventory.ciFiles).Count -gt 0)
    hasDocsPlans = [bool](@($inventory.docsFiles).Count -gt 0)
    hasPackageJson = [bool]$package
    hasFrontendDeps = [bool]($depNames -match "^(react|vue|angular|@angular/core|next|svelte)$")
    hasBackendDeps = [bool]($depNames -match "^(express|fastify|koa|hono|@nestjs/core)$")
    hasTypeScript = (Test-Path -LiteralPath (Join-Path $root "tsconfig.json")) -or [bool]($depNames -match "^(typescript|ts-node)$")
    hasNodeLint = [bool]($scriptNames -match "lint|format") -or [bool]($depNames -match "^(eslint|prettier)$")
    hasNodeTests = [bool]($scriptNames -match "test|vitest|jest|playwright") -or [bool]($depNames -match "^(vitest|jest|@playwright/test)$")
    hasPythonQuality = [bool]($pyprojectText -match "\[tool\.(ruff|black|pytest|mypy|pyright)")
    looksLikeSourceLift = $sourceLiftTextSignal -and $sourceLiftStructuralSignal
    mentionsPricingRules = $allText -match "pricing|margin|markup|quote"
    mentionsProvenance = $allText -match "provenance|confidence|source health|raw-to-canonical"
    codexHooksEnabled = [bool](@($inventory.codex.configSignals.features) -match "hooks\s*=\s*true")
    codexPluginHooksEnabled = [bool](@($inventory.codex.configSignals.features) -match "plugin_hooks\s*=\s*true")
    sendbirdPluginEnabled = [bool](@($inventory.codex.configSignals.pluginSections) -match "cc@sendbird")
    hasSourceLiftSkill = [bool](@($inventory.codex.skills) -contains "sourcelift-catalog-refresh")
}

$recommendations = @{
    Immediate = @()
    Optional = @()
    Avoid = @()
}

if ($signals.looksLikeSourceLift) {
    Add-Rec "Immediate" "AGENTS.md/rules" "Add project rules for source-catalog safety" `
        "This repo is a source-catalog cleanup prototype with raw Excel inputs and generated catalog outputs." `
        "Prevents accidental edits to raw crawl files, records the build command, and keeps future agents from treating generated data as source of truth." `
        "Keep rules short: raw files read-only, generated files replaceable, build command, verification command, and frontend visual check."

    if ($signals.hasSourceLiftSkill) {
        Add-Rec "Immediate" "skill" "Use the existing SourceLift catalog-refresh skill" `
            "The workspace now has a dedicated skill for messy-source ingestion, canonical mapping, pricing/margin review, line-sheet/export QA, and provenance checks." `
            "Future catalog work can start from the exact project workflow instead of a generic coding flow." `
            "Keep it read-first and require explicit approval before durable raw-data edits."
    } else {
        Add-Rec "Immediate" "skill" "Create a SourceLift catalog-refresh skill" `
            "The repeated workflow is not generic coding; it is messy-source ingestion, canonical mapping, pricing/margin review, line-sheet/export QA, and provenance checks." `
            "A dedicated skill will make future catalog imports faster and safer than a broad setup recommender can." `
            "Make it read-first and require explicit approval before durable edits to raw data or generated outputs."
    }

    if ($signals.hasStaticApp) {
        Add-Rec "Optional" "plugin/app" "Use Browser only for visual QA after UI/catalog changes" `
            "The app is a local static catalog UI, so screenshots and interaction checks are useful after frontend changes." `
            "Catches broken layouts, missing images, and filtering/sorting regressions." `
            "Do not attach browser runs to every prompt; run them only after UI-impacting changes."
    }

    Add-Rec "Optional" "command" "Use built-in Codex commands as the lightweight operator surface" `
        "This project needs repeatable review and context setup, but not a heavy custom command/plugin layer yet." `
        "Use `/init` to draft AGENTS.md, `/diff` to inspect local drift, `/review` before merge-risk changes, and `/goal` for longer improvement loops." `
        "Keep project-specific process in skills/rules instead of inventing command files unless Codex adds first-class custom commands."

    if ($signals.hasExcelInputs) {
        Add-Rec "Optional" "plugin/app" "Use Spreadsheets for workbook inspection and export QA" `
            "The product depends on Excel inputs/outputs, not just source code." `
            "Lets Codex inspect sheets, formulas, image/export shape, and generated workbook quality." `
            "Treat original supplier/crawl files as immutable unless the user explicitly asks otherwise."
    }

    Add-Rec "Optional" "automation" "Add a recurring source-health report only after pilots start" `
        "Scheduled checks become valuable when real suppliers or refresh cadences exist." `
        "Turns catalog drift, missing images, and price anomalies into a regular operating report." `
        "Do not schedule recurring runs against prototype data until there is a real cadence and owner."

    Add-Rec "Avoid" "MCP" "Do not add database/SaaS MCP servers yet" `
        "This repo is still a local prototype and productized-service wedge, not a deployed Supabase/Vercel/Slack operating system." `
        "Keeps context, auth, and failure surface small." `
        "Add MCP only when a real external system becomes part of the daily workflow."

    Add-Rec "Avoid" "hook" "Do not run catalog builds or browser checks on every prompt" `
        "The build touches generated artifacts and visual checks are heavier than a cheap guardrail." `
        "Avoids noisy hook failures and slow prompt submission." `
        "Prefer explicit commands or post-change verification."
} else {
    if ($signals.hasLocalSkillBundle -and -not (Test-Path -LiteralPath (Join-Path $root "AGENTS.md"))) {
        Add-Rec "Immediate" "AGENTS.md/rules" "Add project rules for skill-bundle safety" `
            "This repo stores local Agent Skills and deployment scripts, so the repo copy should be the source of truth." `
            "Prevents installed-cache drift, records the verification commands, and keeps bundled skill names from being treated as target-repo identity." `
            "Keep rules short: repo skills are authoritative, installed copies are derived, run self/fixture tests before sync, and separate host Codex context from target repo evidence."
    }

    if ($signals.isGitHub) {
        Add-Rec "Immediate" "plugin/app" "Use GitHub integration for PR and issue work" `
            "The repo remote is on GitHub." `
            "Keeps PR metadata, reviews, and CI triage available without broad custom MCP setup." `
            "Use gh CLI for Actions logs when connector coverage is not enough."
    }

    if ($signals.hasFrontendDeps) {
        Add-Rec "Immediate" "plugin/app" "Use Browser for visual and interaction checks" `
            "Frontend dependencies were detected." `
            "Lets Codex verify rendered UI, screenshots, forms, and responsive behavior instead of only reading code." `
            "Run after UI-impacting changes; do not make it a prompt-submit hook."

        Add-Rec "Optional" "MCP" "Use versioned docs lookup for fast-moving frontend libraries" `
            "Frontend libraries and build tools change quickly." `
            "Reduces stale API assumptions when editing framework code." `
            "Prefer official docs or a narrow docs MCP; do not add broad web/data MCP access by default."
    }

    if ($signals.hasNodeLint -or $signals.hasTypeScript -or $signals.hasNodeTests) {
        Add-Rec "Optional" "hook" "Use cheap JavaScript quality hooks only when scripts exist" `
            "Package scripts or dependencies indicate lint, format, typecheck, or test workflows." `
            "Catches local mistakes quickly without inventing commands." `
            "Start with explicit verification; promote to hooks only after commands are fast and stable."
    }

    if ($signals.hasPythonQuality) {
        Add-Rec "Optional" "hook" "Use Ruff/pytest hooks only after command timing is known" `
            "Python quality tooling was detected in pyproject.toml." `
            "Gives quick feedback for formatting, linting, and tests." `
            "Avoid attaching slow full-suite runs to every edit."
    }
}

if (-not $signals.hasTests) {
    Add-Rec "Immediate" "local environment" "Define a minimal verification command" `
        "No test files were detected, so agents need one known command that proves the core workflow still works." `
        "Reduces false confidence after changes and gives future hooks/skills a stable target." `
        "For this repo, start with the catalog build command and a static-app smoke check."
}

if ($signals.hasDirtyWorktree) {
    Add-Rec "Immediate" "rule" "Document dirty-worktree handling" `
        "The current checkout has modified or untracked files." `
        "Prevents future agents from reverting user work or mixing setup changes with product edits." `
        "Keep setup edits isolated to the skill/config unless the user asks for repo changes."
}

if ($signals.codexHooksEnabled -and $signals.codexPluginHooksEnabled -and $signals.sendbirdPluginEnabled) {
    Add-Rec "Optional" "hook" "Keep existing Claude Code bridge hooks, but avoid cache-path assumptions" `
        "Codex hooks and plugin hooks are enabled, and the Sendbird Claude Code bridge is active." `
        "Preserves the workflow you already use while avoiding the Windows/plugin-cache failure mode seen earlier." `
        "Prefer wrapper scripts or absolute stable paths if hooks need customization."
}

if ($signals.isSmallRepo) {
    Add-Rec "Avoid" "subagent" "Do not create a permanent large-codebase reviewer yet" `
        "The sampled repo is small, so a persistent reviewer subagent would be more overhead than leverage." `
        "Keeps context and coordination simple." `
        "Use ad hoc review agents only for high-risk changes or independent investigations."
} else {
    Add-Rec "Optional" "subagent" "Add read-only code-review subagent" `
        "The repo is large enough that isolated review can help." `
        "Catches regressions without polluting the main context." `
        "Keep it read-only unless explicitly implementing fixes."
}

$profileType = if ($signals.looksLikeSourceLift) {
    "SourceLift / Great Homes Source catalog-cleanup prototype"
} elseif ($signals.hasLocalSkillBundle) {
    "Codex skill bundle"
} elseif ($signals.hasStaticApp) {
    "static web app"
} elseif ($inventory.manifests.javascript) {
    "JavaScript/TypeScript project"
} elseif ($inventory.manifests.python) {
    "Python project"
} else {
    "mixed or lightweight repository"
}

$report = [ordered]@{
    focus = $Focus
    verdict = if ($signals.looksLikeSourceLift) {
        "Worth a focused setup pass: keep the agent setup small, source-safe, and tailored to catalog cleanup."
    } else {
        "Use a light setup pass: add only repo-specific rules and integrations backed by detected workflows."
    }
    detected = [ordered]@{
        stack = $profileType
        filesSampled = $inventory.counts.filesSampled
        branch = $inventory.git.branch
        dirtyWorktree = $signals.hasDirtyWorktree
        riskProfile = Get-RiskProfile
        modelFit = Get-ModelFit
        modelPlan = @(Get-ModelPlan)
        clientPlan = @(Get-ClientPlan)
        nativeFirstSelectionPolicy = @(Get-NativeFirstSelectionPolicy)
        minimalInstallPolicy = @(Get-MinimalInstallPolicy)
        platformCapabilities = @(Get-PlatformCapabilityMatrix)
        safeSourcePolicy = @(Get-SafeSourcePolicy)
        harnessAudit = @(Get-HarnessAudit)
        existingCodex = [ordered]@{
            hooks = $signals.codexHooksEnabled
            pluginHooks = $signals.codexPluginHooksEnabled
            sendbird = $signals.sendbirdPluginEnabled
            skills = @($inventory.codex.skills)
        }
        gaps = @(
            if (-not $signals.hasTests) { "No tests detected" }
            if (-not (Test-Path -LiteralPath (Join-Path $root "AGENTS.md"))) { "No AGENTS.md detected" }
            if ($signals.hasDirtyWorktree) { "Dirty worktree needs care" }
        )
    }
    recommendations = $recommendations
    discussBeforeInstalling = @(Get-DiscussionQuestions)
    implementationPlan = @(Get-SetupPlan)
    verifyPlan = @(Get-VerifyPlan)
}

if ($Json) {
    if ($Focus -ne "all") {
        foreach ($bucket in @("Immediate", "Optional", "Avoid")) {
            $report.recommendations[$bucket] = @($report.recommendations[$bucket] | Where-Object { Test-FocusMatch $_ })
        }
    }
    $report | ConvertTo-Json -Depth 8
    exit 0
}

Write-Output "**Verdict**"
Write-Output $report.verdict
Write-Output ""
Write-Output "**Detected**"
Write-Output "- Stack: $($report.detected.stack)"
Write-Output "- Branch: $($report.detected.branch)"
Write-Output "- Files sampled: $($report.detected.filesSampled)"
Write-Output "- Dirty worktree: $($report.detected.dirtyWorktree)"
Write-Output "- Risk profile: $($report.detected.riskProfile)"
Write-Output "- Model fit: $($report.detected.modelFit)"
Write-Output "- Host Codex context: hooks=$($report.detected.existingCodex.hooks), plugin_hooks=$($report.detected.existingCodex.pluginHooks), Sendbird=$($report.detected.existingCodex.sendbird)"
if ($report.detected.gaps.Count -gt 0) {
    Write-Output "- Gaps: $($report.detected.gaps -join '; ')"
}

Write-Output ""
Write-Output "**Safe Source Policy**"
foreach ($policy in $report.detected.safeSourcePolicy) {
    Write-Output "- $policy"
}

Write-Output ""
Write-Output "**Native-First Skill Selection**"
foreach ($policy in $report.detected.nativeFirstSelectionPolicy) {
    Write-Output "- $policy"
}

Write-Output ""
Write-Output "**Minimal Install Policy**"
foreach ($policy in $report.detected.minimalInstallPolicy) {
    Write-Output "- $policy"
}

Write-Output ""
Write-Output "**Harness Audit**"
foreach ($item in $report.detected.harnessAudit) {
    Write-Output "- $item"
}

foreach ($bucket in @("Immediate", "Optional", "Avoid")) {
    Write-Output ""
    Write-Output "**$bucket**"
    $items = @($report.recommendations[$bucket] | Where-Object { Test-FocusMatch $_ } | Select-Object -First 5)
    if ($items.Count -eq 0) {
        Write-Output "- No strong $Focus recommendation for this bucket."
        continue
    }
    foreach ($rec in $items) {
        $line = "- [$($rec.mechanism)] $($rec.title) - $($rec.reason) Benefit: $($rec.benefit)"
        if ($rec.safety) { $line += " Safety: $($rec.safety)" }
        if ($rec.fitEvidence) { $line += " Fit: $($rec.fitEvidence)" }
        if ($rec.confirmation) { $line += " Confirm: $($rec.confirmation)" }
        Write-Output $line
    }
}

Write-Output ""
Write-Output "**Model Plan**"
for ($i = 0; $i -lt $report.detected.modelPlan.Count; $i++) {
    Write-Output "$($i + 1). $($report.detected.modelPlan[$i])"
}

Write-Output ""
Write-Output "**Client Plan**"
for ($i = 0; $i -lt $report.detected.clientPlan.Count; $i++) {
    Write-Output "$($i + 1). $($report.detected.clientPlan[$i])"
}

Write-Output ""
Write-Output "**Platform Capability Matrix**"
foreach ($platform in $report.detected.platformCapabilities) {
    $caps = $platform.capabilities
    $sources = @($platform.sourceAuthority.sources) -join ", "
    Write-Output "- $($platform.client) [$($platform.confidence); sources=$($platform.sourceAuthority.status)]: context=$($caps.context); skills=$($caps.skills); MCP=$($caps.mcp); hooks=$($caps.hooks); commands=$($caps.commands); agents=$($caps.agents); permissions=$($caps.permissions); verify=$($platform.verification); source=$sources"
}

Write-Output ""
Write-Output "**Discuss Before Installing**"
for ($i = 0; $i -lt $report.discussBeforeInstalling.Count; $i++) {
    Write-Output "$($i + 1). $($report.discussBeforeInstalling[$i])"
}

Write-Output ""
Write-Output "**Implementation Plan**"
for ($i = 0; $i -lt $report.implementationPlan.Count; $i++) {
    Write-Output "$($i + 1). $($report.implementationPlan[$i])"
}

Write-Output ""
Write-Output "**Verify Setup**"
for ($i = 0; $i -lt $report.verifyPlan.Count; $i++) {
    Write-Output "$($i + 1). $($report.verifyPlan[$i])"
}
