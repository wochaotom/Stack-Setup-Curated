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
    if ($signals.codexHooksEnabled -or $signals.codexPluginHooksEnabled) { $risks += "hook execution" }
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
        "Prefer OpenAI skills catalog and `$skill-installer when the confirmed target is Codex.",
        "Use Agent Skills, Anthropic skills, GitHub Copilot, Cursor, and Google Antigravity official docs as reference or compatibility sources with review.",
        "Treat broad community directories as discovery-only and inspect original repos before recommending.",
        'Reject `officialskills.sh` as a vetted source.'
    )
}

function Get-ClientPlan() {
    return @(
        "Codex: AGENTS.md/rules, curated plugins/apps, `$skill-installer, explicit verification commands, and worktree/local environment setup.",
        "Claude Code: CLAUDE.md, plugins, skills, agents/subagents, hooks, MCP, and slash commands when Claude parity is required.",
        "GitHub Copilot: portable Agent Skills and GitHub-hosted skill guidance after previewing skills because community skills are not verified.",
        "Cursor: `.cursor/rules` for persistent guidance and Cursor MCP via `mcp.json` or `cursor-agent mcp`; do not copy Codex hooks blindly.",
        "Antigravity: MCP store or `~/.gemini/antigravity/mcp_config.json`, permission controls, and CLI plugin bundles with skills, agents, rules, MCP servers, and hooks."
    )
}

function Get-HarnessAudit() {
    $context = "Context: check AGENTS.md/CLAUDE.md/.cursor/rules/Antigravity rules and keep always-loaded guidance as a router to deeper docs."
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
    $questions += "Which AI clients should this repo actually support: Codex only, Claude Code parity, GitHub Copilot, Cursor, Antigravity, or cross-client Agent Skills?"
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
            "Write or update AGENTS.md/rules with source-catalog boundaries, verification commands, and raw/generated file policy.",
            $skillStep,
            "Run the catalog build, JSON/workbook checks, and one UI smoke workflow before adding hooks or automations."
        )
    }
    return @(
        "Confirm the discussion answers, especially target AI clients, autonomy level, and model budget.",
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
    if ($signals.looksLikeSourceLift) { $evidence += "SourceLift/Great Homes Source signals in README/docs" }
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
    hasStaticApp = Test-Path -LiteralPath (Join-Path $root "app\index.html")
    hasCatalogBuilder = Test-Path -LiteralPath (Join-Path $root "scripts\build_catalog.py")
    hasExcelInputs = [bool]((Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.xlsx" -ErrorAction SilentlyContinue | Select-Object -First 1))
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
    looksLikeSourceLift = $allText -match "SourceLift|Great Homes Source|Moorizon|source catalog|line sheet|quote-ready"
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
Write-Output "- Existing Codex hooks: hooks=$($report.detected.existingCodex.hooks), plugin_hooks=$($report.detected.existingCodex.pluginHooks), Sendbird=$($report.detected.existingCodex.sendbird)"
if ($report.detected.gaps.Count -gt 0) {
    Write-Output "- Gaps: $($report.detected.gaps -join '; ')"
}

Write-Output ""
Write-Output "**Safe Source Policy**"
foreach ($policy in $report.detected.safeSourcePolicy) {
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
