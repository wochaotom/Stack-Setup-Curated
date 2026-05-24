$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$required = @(
    "repo-scorecards.tsv",
    "skill-taxonomy.tsv",
    "executable-surface.tsv",
    "marketplace-packaging-findings.tsv",
    "reusable-patterns.tsv",
    "risk-register.tsv",
    "import-candidates.tsv",
    "conversion-opportunities.tsv",
    "source-policy-upgrades.md",
    "final-distillation-report.md",
    "verify_distillation.ps1"
)

function Get-DataRows($FileName) {
    $path = Join-Path $root $FileName
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $lines = @(Get-Content -LiteralPath $path | Where-Object { $_.Trim().Length -gt 0 })
    if ($lines.Count -le 1) { return @() }
    return @($lines | Select-Object -Skip 1)
}

function Test-NonEmpty($FileName) {
    $path = Join-Path $root $FileName
    return (Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path).Length -gt 0)
}

$score = 0
$details = [ordered]@{}

$present = @($required | Where-Object { Test-NonEmpty $_ })
$score += $present.Count * 10
$details.required_present = $present.Count

$taxonomyRows = Get-DataRows "skill-taxonomy.tsv"
$taxonomyCount = $taxonomyRows.Count
$score += [Math]::Min($taxonomyCount, 80)
$details.taxonomy_rows = $taxonomyCount

$patternRows = Get-DataRows "reusable-patterns.tsv"
$patternCount = $patternRows.Count
$score += [Math]::Min($patternCount * 2, 80)
$details.reusable_patterns = $patternCount

$improvements = @($patternRows | Where-Object {
        $parts = $_ -split "`t"
        $parts.Count -ge 6 -and $parts[5].Trim().Length -gt 0
    }).Count
$score += [Math]::Min($improvements * 3, 90)
$details.improvement_candidates = $improvements

$riskRows = Get-DataRows "risk-register.tsv"
$riskCount = $riskRows.Count
$score += [Math]::Min($riskCount * 3, 60)
$details.risk_rules = $riskCount

$candidateRows = Get-DataRows "import-candidates.tsv"
$classifiedCandidates = @($candidateRows | Where-Object {
        $parts = $_ -split "`t"
        $parts.Count -ge 6 -and $parts[3] -match "^(keep|convert|link|reject)$" -and $parts[4].Trim().Length -gt 0 -and $parts[5].Trim().Length -gt 0
    }).Count
$score += [Math]::Min($classifiedCandidates * 5, 100)
$details.classified_candidates = $classifiedCandidates

$scorecards = Get-Content -LiteralPath (Join-Path $root "repo-scorecards.tsv") -Raw
if ($scorecards -match "0f429d0f96ee70d2a6c259c4ecc6c6e18e0d23ff" -and $scorecards -match "9b2ef9eae161c00a17241d42a388571321b33e9f") {
    $score += 50
    $details.pinned_shas = $true
} else {
    $details.pinned_shas = $false
}

$finalReport = Get-Content -LiteralPath (Join-Path $root "final-distillation-report.md") -Raw
if ($finalReport -match "Prioritized Next Actions" -and $finalReport -match "source scorecards") {
    $score += 50
    $details.prioritized_next_actions = $true
} else {
    $details.prioritized_next_actions = $false
}

if ($finalReport -match "Executed third-party script:\s*true") {
    $score -= 100
    $details.third_party_script_executed_penalty = $true
} else {
    $details.third_party_script_executed_penalty = $false
}

$allArtifactText = ($required | Where-Object { $_ -ne "verify_distillation.ps1" } | ForEach-Object {
        $path = Join-Path $root $_
        if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw }
    }) -join "`n"

$placeholderPattern = ("TO" + "DO") + "|" + ("TB" + "D")
if ($allArtifactText -match $placeholderPattern) {
    $score -= 100
    $details.placeholder_penalty = $true
} else {
    $details.placeholder_penalty = $false
}

$legalAuthorityPattern = ("authoritative " + "legal conclusion") + "|" + ("no counsel " + "needed") + "|" + ("guarantees " + "compliance")
if ($finalReport -match $legalAuthorityPattern) {
    $score -= 100
    $details.legal_authority_penalty = $true
} else {
    $details.legal_authority_penalty = $false
}

$details.distillation_score = $score

Write-Output "distillation_score=$score"
Write-Output ($details | ConvertTo-Json -Depth 4)

if ($score -lt 500) { exit 1 }
