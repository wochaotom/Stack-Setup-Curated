param(
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditPath = Join-Path $scriptDir "audit.ps1"
$skillPath = Join-Path (Split-Path -Parent $scriptDir) "SKILL.md"
$yamlPath = Join-Path (Split-Path -Parent $scriptDir) "agents\openai.yaml"

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

Add-Check "skill frontmatter" ($skill -match "^---" -and $skill -match "name:\s*codex-setup-audit" -and $skill -match "description:\s*Use when")
Add-Check "ui metadata" ($yaml -match "display_name: `"Codex Setup Audit`"" -and $yaml -match "\$codex-setup-audit")
Add-Check "read-only rule" ($skill -match "Default to read-only" -and $auditText -notmatch "Install .* now|Enable .* now")
Add-Check "core categories" ($skill -match "MCP" -and $skill -match "hooks" -and $skill -match "subagents" -and $skill -match "slash commands" -and $skill -match "automations")
Add-Check "external skill discovery gated" ($skill -match "OpenAI skills catalog" -and $skill -match "OpenAI skill-installer curated listing" -and $skill -match "Discovery-only: VoltAgent/awesome-agent-skills")
Add-Check "officialskills not qualified" ($skill -match "Rejected as vetted source: officialskills\.sh" -and $skill -match "do not call it official, trusted, or vetted")
Add-Check "standard and upstream references" ($skill -match "Agent Skills standard" -and $skill -match "Anthropic skills repository" -and $skill -match "GitHub Copilot agent skills docs")
Add-Check "source project fit" ($auditText -match "SourceLift|Great Homes Source|catalog-cleanup|source-catalog" -and $auditText -match "raw")
Add-Check "uses companion skill when present" ($auditText -match "existing SourceLift catalog-refresh skill")
Add-Check "next steps do not recreate companion" ($auditText -match "\$sourcelift-catalog-refresh" -and $auditText -notmatch "Create a SourceLift-specific catalog-refresh skill if")
Add-Check "safe avoid bucket" ($auditJson.recommendations.Avoid.Count -gt 0)
Add-Check "codex command surface" ($auditText -match "/init" -and $auditText -match "/diff" -and $auditText -match "/review" -and $auditText -match "/goal")
Add-Check "automation is gated" ($auditText -match "after pilots start" -and $auditText -match "Do not schedule")
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

if ($failed.Count -gt 0) { exit 1 }
