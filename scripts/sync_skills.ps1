param(
    [string]$SourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$Destination = (Join-Path $env:USERPROFILE ".codex\skills"),
    [string[]]$SkillName = @(),
    [switch]$SkipTests,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-RelativeFileHashes($Root) {
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $manifest = @{}
    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force | ForEach-Object {
        $relative = [System.IO.Path]::GetRelativePath($resolvedRoot, $_.FullName)
        $manifest[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
    }
    return $manifest
}

function Assert-ChildPath($Parent, $Child) {
    $parentFull = (Resolve-Path -LiteralPath $Parent).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $childParent = Split-Path -Parent $Child
    if (-not (Test-Path -LiteralPath $childParent)) {
        New-Item -ItemType Directory -Force -Path $childParent | Out-Null
    }
    $childFull = [System.IO.Path]::GetFullPath($Child)
    $prefix = $parentFull + [System.IO.Path]::DirectorySeparatorChar
    if (-not $childFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside destination: $childFull"
    }
}

function Compare-Manifests($SourceManifest, $DestinationManifest) {
    $sourcePaths = @($SourceManifest.Keys)
    $destinationPaths = @($DestinationManifest.Keys)
    $missing = @($sourcePaths | Where-Object { -not $DestinationManifest.ContainsKey($_) } | Sort-Object)
    $extra = @($destinationPaths | Where-Object { -not $SourceManifest.ContainsKey($_) } | Sort-Object)
    $mismatch = @($sourcePaths | Where-Object {
            $DestinationManifest.ContainsKey($_) -and $SourceManifest[$_] -ne $DestinationManifest[$_]
        } | Sort-Object)

    return [ordered]@{
        missingFiles = $missing
        extraFiles = $extra
        hashMismatches = $mismatch
        hashesMatch = ($missing.Count -eq 0 -and $extra.Count -eq 0 -and $mismatch.Count -eq 0)
    }
}

function Invoke-InstalledTest($Name, $ScriptPath, $Arguments) {
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        return [ordered]@{
            name = $Name
            passed = $false
            exitCode = $null
            output = "Missing test script: $ScriptPath"
        }
    }

    $psExe = (Get-Process -Id $PID).Path
    $output = & $psExe -NoProfile -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    return [ordered]@{
        name = $Name
        passed = ($exitCode -eq 0)
        exitCode = $exitCode
        output = ($output -join "`n")
    }
}

$sourceSkillsRoot = Join-Path $SourceRoot "skills"
if (-not (Test-Path -LiteralPath $sourceSkillsRoot)) {
    throw "Source skills directory not found: $sourceSkillsRoot"
}

$destinationRoot = [System.IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
$destinationRoot = (Resolve-Path -LiteralPath $destinationRoot).Path

$sourceRootFull = (Resolve-Path -LiteralPath $SourceRoot).Path
if ($destinationRoot.StartsWith($sourceRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination must not be inside the source repository: $destinationRoot"
}

if ($SkillName.Count -eq 0) {
    $SkillName = @(Get-ChildItem -LiteralPath $sourceSkillsRoot -Directory -Force | Select-Object -ExpandProperty Name | Sort-Object)
}

$skillResults = @()
foreach ($name in $SkillName) {
    $sourceSkill = Join-Path $sourceSkillsRoot $name
    if (-not (Test-Path -LiteralPath $sourceSkill)) {
        throw "Source skill not found: $sourceSkill"
    }

    $targetSkill = Join-Path $destinationRoot $name
    Assert-ChildPath $destinationRoot $targetSkill

    if (Test-Path -LiteralPath $targetSkill) {
        Remove-Item -LiteralPath $targetSkill -Recurse -Force
    }
    Copy-Item -LiteralPath $sourceSkill -Destination $destinationRoot -Recurse -Force

    $sourceManifest = Get-RelativeFileHashes $sourceSkill
    $destinationManifest = Get-RelativeFileHashes $targetSkill
    $comparison = Compare-Manifests $sourceManifest $destinationManifest

    $skillResults += [ordered]@{
        name = $name
        copied = (Test-Path -LiteralPath (Join-Path $targetSkill "SKILL.md"))
        sourceFileCount = $sourceManifest.Count
        destinationFileCount = $destinationManifest.Count
        hashesMatch = $comparison.hashesMatch
        missingFiles = $comparison.missingFiles
        extraFiles = $comparison.extraFiles
        hashMismatches = $comparison.hashMismatches
    }
}

$testResults = @()
if (-not $SkipTests) {
    $installedAuditScripts = Join-Path $destinationRoot "codex-setup-audit\scripts"
    $testResults += Invoke-InstalledTest "installed setup-audit self test" (Join-Path $installedAuditScripts "self_test.ps1") @("-Path", $SourceRoot)
    $testResults += Invoke-InstalledTest "installed setup-audit fixture test" (Join-Path $installedAuditScripts "fixture_test.ps1") @()
}

$success = (@($skillResults | Where-Object { -not $_.copied -or -not $_.hashesMatch }).Count -eq 0) -and
    ($SkipTests -or @($testResults | Where-Object { -not $_.passed }).Count -eq 0)

$result = [ordered]@{
    success = $success
    sourceRoot = $sourceRootFull
    destination = $destinationRoot
    skills = $skillResults
    testsSkipped = [bool]$SkipTests
    tests = $testResults
}

if ($Json) {
    $result | ConvertTo-Json -Depth 10
} else {
    if ($success) {
        Write-Output "Skill sync succeeded."
    } else {
        Write-Output "Skill sync failed."
    }
    Write-Output "Source: $($result.sourceRoot)"
    Write-Output "Destination: $($result.destination)"
    foreach ($skill in $skillResults) {
        Write-Output "- $($skill.name): copied=$($skill.copied), hashesMatch=$($skill.hashesMatch), files=$($skill.destinationFileCount)"
    }
    foreach ($test in $testResults) {
        Write-Output "- $($test.name): passed=$($test.passed), exitCode=$($test.exitCode)"
    }
}

if (-not $success) { exit 1 }
