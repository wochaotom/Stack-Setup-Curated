param(
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditPath = Join-Path $scriptDir "audit.ps1"
$convertPath = Join-Path $scriptDir "convert_skill.ps1"
$skillPath = Join-Path (Split-Path -Parent $scriptDir) "SKILL.md"
$yamlPath = Join-Path (Split-Path -Parent $scriptDir) "agents\openai.yaml"
$tmpRoot = Join-Path $env:TEMP ("codex-setup-audit-self-" + [guid]::NewGuid().ToString("N"))

$checks = @()

function Add-Check($Name, $Pass, $Detail = "") {
    $script:checks += [ordered]@{
        name = $Name
        pass = [bool]$Pass
        detail = $Detail
    }
}

$skill = Get-Content -LiteralPath $skillPath -Raw
$yaml = Get-Content -LiteralPath $yamlPath -Raw
$auditText = & $auditPath -Path $Path
$auditJson = & $auditPath -Path $Path -Json | ConvertFrom-Json
$hookFocus = & $auditPath -Path $Path -Focus hooks
$inventoryJson = & (Join-Path $scriptDir "inventory.ps1") -Path $Path | ConvertFrom-Json
$conversionJson = $null
$complexConversionJson = $null
$unsupportedConversionJson = $null
$blockedConversionExitCode = $null
$unsupportedConversionExitCode = $null
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $tmpRoot "simple-skill") | Out-Null
    Set-Content -LiteralPath (Join-Path $tmpRoot "simple-skill\SKILL.md") -Encoding UTF8 -Value @'
---
name: portable-review
description: Use when reviewing portable skill conversion fixtures.
---

# Portable Review

Follow the review checklist and stop if evidence is missing.
'@
    New-Item -ItemType Directory -Force -Path (Join-Path $tmpRoot "complex-skill\scripts") | Out-Null
    Set-Content -LiteralPath (Join-Path $tmpRoot "complex-skill\SKILL.md") -Encoding UTF8 -Value @'
---
name: complex-review
description: Use when testing complex conversion blocking.
---

# Complex Review

Run `scripts/check.ps1` before reporting.
'@
    Set-Content -LiteralPath (Join-Path $tmpRoot "complex-skill\scripts\check.ps1") -Encoding UTF8 -Value "Write-Output 'checked'"
    if (Test-Path -LiteralPath $convertPath) {
        $conversionJson = & $convertPath -SourcePath (Join-Path $tmpRoot "simple-skill") -Target "github-copilot" -OutputPath (Join-Path $tmpRoot "converted") -Json | ConvertFrom-Json
        $psExe = (Get-Process -Id $PID).Path
        $complexConversionOutput = & $psExe -NoProfile -File $convertPath -SourcePath (Join-Path $tmpRoot "complex-skill") -Target "continue" -OutputPath (Join-Path $tmpRoot "blocked") -Json 2>$null
        $blockedConversionExitCode = $LASTEXITCODE
        $complexConversionJson = $complexConversionOutput | ConvertFrom-Json
        $unsupportedConversionOutput = & $psExe -NoProfile -File $convertPath -SourcePath (Join-Path $tmpRoot "simple-skill") -Target "not-a-real-target" -OutputPath (Join-Path $tmpRoot "unsupported") -Json 2>$null
        $unsupportedConversionExitCode = $LASTEXITCODE
        $unsupportedConversionJson = $unsupportedConversionOutput | ConvertFrom-Json
    }
} catch {
    $conversionJson = $null
    $complexConversionJson = $null
    $unsupportedConversionJson = $null
}

Add-Check "skill frontmatter" ($skill -match "^---" -and $skill -match "name:\s*codex-setup-audit" -and $skill -match "description:\s*Use when")
Add-Check "ui metadata" ($yaml -match "display_name: `"Agent Setup Audit`"" -and $yaml -match "\$codex-setup-audit")
Add-Check "read-only rule" ($skill -match "Default to read-only" -and $auditText -notmatch "Install .* now|Enable .* now")
Add-Check "core categories" ($skill -match "MCP" -and $skill -match "hooks" -and $skill -match "subagents" -and $skill -match "slash commands" -and $skill -match "automations")
Add-Check "claude setup baseline extended" ($skill -match "Baseline reference" -and $skill -match "Claude Code Setup" -and $skill -match "go further than one-client setup")
Add-Check "fit framework present" ($skill -match "workflow fit" -and $skill -match "safety fit" -and $skill -match "user fit")
Add-Check "harness framework present" ($skill -match "Vault-derived operating lens" -and $skill -match "Audit the harness" -and $skill -match "permission gates" -and $skill -match "cross-model")
Add-Check "model guidance present" ($skill -match "Fast/cheap model" -and $skill -match "Strong coding model" -and $skill -match "Cross-model support")
Add-Check "external skill discovery gated" ($skill -match "OpenAI skills catalog" -and $skill -match "OpenAI skill-installer curated listing" -and $skill -match "Discovery-only: VoltAgent/awesome-agent-skills")
Add-Check "officialskills not qualified" ($skill -match "Rejected as vetted source: officialskills\.sh" -and $skill -match "do not call it official, trusted, or vetted")
Add-Check "standard and upstream references" ($skill -match "Agent Skills standard" -and $skill -match "Anthropic skills repository" -and $skill -match "GitHub Copilot agent skills docs")
Add-Check "cursor and antigravity references" ($skill -match "Cursor official docs" -and $skill -match "Google Antigravity official docs" -and $skill -match "\.cursor/rules" -and $skill -match "antigravity-cli")
Add-Check "github community index caveated" ($skill -match "github/awesome-copilot" -and $skill -match "not verified")
Add-Check "marketplace-only source policy" ($skill -match "Any marketplace can be a candidate acquisition source" -and $skill -match "only exists there" -and $skill -match "license, scripts, install steps")
Add-Check "native-first selection policy" ($skill -match "Native-First Selection Policy" -and $skill -match "Target-native exact match" -and $skill -match "Target-native adjacent match" -and $skill -match "Cross-platform source" -and $skill -match "Marketplace-only source" -and $skill -match "Do not make Codex the source of truth")
Add-Check "minimal install policy" ($skill -match "Minimal Install Policy" -and $skill -match "smallest reviewed install" -and $skill -match "Narrow domain bundle" -and $skill -match "Complete bundle or broad stack")
Add-Check "platform neutral framing" ($skill -match "capabilities first" -and $skill -match "client adapters" -and $skill -match "Do not make Codex the default answer")
Add-Check "audit emits risk and model fit" ($auditText -match "Risk profile:" -and $auditText -match "Model fit:")
Add-Check "audit emits safe source policy" ($auditText -match "Safe Source Policy" -and $auditText -match 'Reject `?officialskills\.sh`?')
Add-Check "audit emits native-first selection policy" ($auditText -match "Native-First Skill Selection" -and $auditText -match "Target-native exact match" -and $auditText -match "Claude Code and Codex first" -and $auditText -match "Marketplace-only source")
Add-Check "audit emits minimal install policy" ($auditText -match "Minimal Install Policy" -and $auditText -match "Default to no install" -and $auditText -match "narrow domain bundles" -and $auditText -match "bloat")
Add-Check "audit emits harness audit" ($auditText -match "Harness Audit" -and $auditText -match "Tools/MCP:" -and $auditText -match "human-gate" -and $auditText -match "cross-model/reviewer")
Add-Check "powershell skill tests detected" (@($inventoryJson.testFiles | Where-Object { $_ -match "self_test\.ps1|fixture_test\.ps1" }).Count -ge 2)
Add-Check "audit does not report false missing tests" (@($auditJson.detected.gaps | Where-Object { $_ -eq "No tests detected" }).Count -eq 0 -and $auditJson.detected.riskProfile -notmatch "weak mechanical verification" -and @($auditJson.detected.harnessAudit | Where-Object { $_ -match "no tests detected" }).Count -eq 0)
Add-Check "audit emits model plan" ($auditText -match "Model Plan" -and $auditText -match "Fast model:" -and $auditText -match "Strongest/review model:")
Add-Check "audit emits client plan" ($auditText -match "Client Plan" -and $auditText -match "\.cursor/rules" -and $auditText -match "Antigravity:")
Add-Check "audit emits platform matrix" ($auditText -match "Platform Capability Matrix" -and $auditText -match "OpenCode" -and $auditText -match "Aider" -and $auditText -match "Continue" -and $auditText -match "Cline" -and $auditText -match "Roo Code" -and $auditText -match "Windsurf")
Add-Check "audit emits discussion plan" ($auditText -match "Discuss Before Installing" -and $auditText -match "target AI clients" -and $auditText -match "cross-ecosystem marketplaces" -and $auditText -match "smallest install" -and $auditText -match "Cursor" -and $auditText -match "Antigravity")
Add-Check "audit emits staged setup plan" ($auditText -match "Implementation Plan" -and $auditText -match "Verify Setup" -and $auditText -match "Run ")
Add-Check "recommendations include nonduplicate fit" ($auditText -match " Fit: " -and $auditText -notmatch "Fit: This repo is a source-catalog cleanup prototype")
Add-Check "verify command renders literally" ($auditText -match 'audit\.ps1 -Json' -and $auditText -notmatch ([string][char]7))
Add-Check "json emits new setup keys" ($auditJson.detected.safeSourcePolicy.Count -gt 0 -and $auditJson.detected.modelPlan.Count -gt 0 -and $auditJson.detected.clientPlan.Count -gt 0 -and $auditJson.detected.nativeFirstSelectionPolicy.Count -gt 0 -and $auditJson.detected.minimalInstallPolicy.Count -gt 0 -and $auditJson.detected.harnessAudit.Count -gt 0 -and $auditJson.implementationPlan.Count -gt 0 -and $auditJson.verifyPlan.Count -gt 0)
Add-Check "json emits platform matrix" ($auditJson.detected.platformCapabilities.Count -ge 11 -and @($auditJson.detected.platformCapabilities | Where-Object { $_.client -eq "Windsurf" -and $_.confidence -eq "docs-backed" }).Count -eq 1)
Add-Check "platform capabilities are populated" (@($auditJson.detected.platformCapabilities | Where-Object { -not $_.capabilities.context -or -not $_.verification }).Count -eq 0)
Add-Check "platform sources are official" (@($auditJson.detected.platformCapabilities | Where-Object { $_.sourceAuthority.status -ne "official" -or @($_.sourceAuthority.sources).Count -eq 0 }).Count -eq 0)
Add-Check "unsafe opencode mirror absent" (@($auditJson.detected.platformCapabilities | Where-Object { (@($_.sourceAuthority.sources) -join " ") -match "open-code\.ai" }).Count -eq 0)
Add-Check "converter script exists" (Test-Path -LiteralPath $convertPath)
Add-Check "converter emits native skill" ($conversionJson.success -eq $true -and $conversionJson.status -eq "converted" -and @($conversionJson.generatedFiles | Where-Object { $_ -match "\.github[\\/]skills[\\/]portable-review[\\/]SKILL\.md$" }).Count -eq 1)
Add-Check "converter blocks lossy complex conversion" ($complexConversionJson.success -eq $false -and $complexConversionJson.status -eq "blocked" -and $complexConversionJson.reason -match "supporting files")
Add-Check "converter blocked and unsupported conversions exit nonzero" ($blockedConversionExitCode -ne 0 -and $unsupportedConversionExitCode -ne 0 -and $unsupportedConversionJson.success -eq $false -and $unsupportedConversionJson.status -eq "unsupported")
Add-Check "json fit evidence populated" (@($auditJson.recommendations.Immediate + $auditJson.recommendations.Optional + $auditJson.recommendations.Avoid | Where-Object { -not $_.fitEvidence }).Count -eq 0)
Add-Check "skill bundle profile" ($auditJson.detected.stack -eq "Codex skill bundle" -and $auditText -notmatch "catalog-cleanup prototype|source-catalog cleanup prototype|catalog build command")
Add-Check "bundled skill names do not drive target fit" ($auditText -notmatch "existing SourceLift catalog-refresh skill|source-catalog safety|\$sourcelift-catalog-refresh")
Add-Check "safe avoid bucket" ($auditJson.recommendations.Avoid.Count -gt 0)
Add-Check "command mechanism covered" ($skill -match "Slash commands: recommend" -and $skill -match "repeatable operator actions")
Add-Check "automation is gated" ($skill -match "Automations: recommend only" -and $auditText -notmatch "recurring source-health report")
Add-Check "focus mode filters" ($hookFocus -match "\[hook\]" -and $hookFocus -notmatch "\[skill\] Create")
Add-Check "bounded recs" ($auditJson.recommendations.Immediate.Count -le 4 -and $auditJson.recommendations.Optional.Count -le 5)
Add-Check "windows hook risk covered" ($skill -match "Windows path" -and $skill -match "cache paths")

$passed = @($checks | Where-Object { $_.pass }).Count
$failed = @($checks | Where-Object { -not $_.pass })

[ordered]@{
    passed = $passed
    failed = $failed.Count
    checks = $checks
} | ConvertTo-Json -Depth 5

if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}
if ($failed.Count -gt 0) { exit 1 }
