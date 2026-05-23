param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$syncScript = Join-Path $PSScriptRoot "sync_skills.ps1"
$tmpDest = Join-Path $env:TEMP ("stack-setup-sync-test-" + [guid]::NewGuid().ToString("N"))
$checks = @()

function Add-Check($Name, $Pass, $Detail = "") {
    $script:checks += [ordered]@{
        name = $Name
        pass = [bool]$Pass
        detail = $Detail
    }
}

try {
    New-Item -ItemType Directory -Force -Path $tmpDest | Out-Null

    Add-Check "sync script exists" (Test-Path -LiteralPath $syncScript)

    if (Test-Path -LiteralPath $syncScript) {
        $json = & $syncScript -SourceRoot $repoRoot -Destination $tmpDest -SkipTests -Json
        $result = $json | ConvertFrom-Json

        Add-Check "sync reports success" ($result.success -eq $true)
        Add-Check "sync copies all skills" (@($result.skills | Where-Object { $_.copied -eq $true }).Count -eq 3)
        Add-Check "sync verifies hashes" (@($result.skills | Where-Object { $_.hashesMatch -eq $true }).Count -eq 3)
        Add-Check "sync reports no mismatches" (@($result.skills | Where-Object { $_.missingFiles.Count -gt 0 -or $_.extraFiles.Count -gt 0 -or $_.hashMismatches.Count -gt 0 }).Count -eq 0)
        Add-Check "sync destination has setup audit" (Test-Path -LiteralPath (Join-Path $tmpDest "codex-setup-audit\SKILL.md"))
    }

    $failed = @($checks | Where-Object { -not $_.pass })
    [ordered]@{
        passed = @($checks | Where-Object { $_.pass }).Count
        failed = $failed.Count
        checks = $checks
    } | ConvertTo-Json -Depth 8

    if ($failed.Count -gt 0) { exit 1 }
} finally {
    if (Test-Path -LiteralPath $tmpDest) {
        Remove-Item -LiteralPath $tmpDest -Recurse -Force
    }
}
