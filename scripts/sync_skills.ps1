param(
    [string]$SourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$Destination = (Join-Path $env:USERPROFILE ".codex\skills"),
    [string[]]$SkillName = @(),
    [switch]$SkipTests,
    [switch]$Json,
    [switch]$UpdateLock,
    [switch]$SkipLock,
    [switch]$SkipScan
)

$ErrorActionPreference = "Stop"

function Get-RelativePathCompat($BasePath, $FullPath) {
    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $targetFull = [System.IO.Path]::GetFullPath($FullPath)
    $baseUri = [System.Uri]::new($baseFull)
    $targetUri = [System.Uri]::new($targetFull)
    $relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
    return $relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
}

function Get-RelativeFileHashes($Root) {
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $manifest = @{}
    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        $relative = Get-RelativePathCompat $resolvedRoot $_.FullName
        $manifest[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
    }
    return $manifest
}

function Convert-ManifestToEntries($Manifest) {
    return @($Manifest.Keys | Sort-Object | ForEach-Object {
            [ordered]@{
                path = $_
                sha256 = $Manifest[$_]
            }
        })
}

function Get-ManifestBundleHash($Manifest) {
    $lines = @($Manifest.Keys | Sort-Object | ForEach-Object {
            "$_`t$($Manifest[$_])"
        })
    $text = $lines -join "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $hashBytes = $sha.ComputeHash($bytes)
        return (($hashBytes | ForEach-Object { $_.ToString("x2") }) -join "").ToUpperInvariant()
    } finally {
        $sha.Dispose()
    }
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

function New-SkillsLock($SourceSkillsRoot, $Names) {
    $skills = @()
    foreach ($name in @($Names | Sort-Object)) {
        $skillRoot = Join-Path $SourceSkillsRoot $name
        $manifest = Get-RelativeFileHashes $skillRoot
        $skills += [ordered]@{
            name = $name
            bundleSha256 = Get-ManifestBundleHash $manifest
            files = Convert-ManifestToEntries $manifest
        }
    }

    return [ordered]@{
        version = 1
        algorithm = "SHA256"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        skills = $skills
    }
}

function Convert-LockFilesToManifest($Files) {
    $manifest = @{}
    foreach ($file in @($Files)) {
        $manifest[$file.path] = $file.sha256
    }
    return $manifest
}

function Test-SkillsLock($SourceSkillsRoot, $Lock, $Names) {
    $violations = @()

    if ($null -eq $Lock) {
        return [ordered]@{
            verified = $false
            violations = @([ordered]@{
                    skill = $null
                    type = "missing-lock"
                    path = $null
                    message = "skills-lock.json is required before syncing."
                })
        }
    }

    if ($Lock.version -ne 1 -or $Lock.algorithm -ne "SHA256") {
        $violations += [ordered]@{
            skill = $null
            type = "unsupported-lock"
            path = $null
            message = "skills-lock.json must use version 1 and SHA256."
        }
    }

    foreach ($name in @($Names | Sort-Object)) {
        $skillRoot = Join-Path $SourceSkillsRoot $name
        $sourceManifest = Get-RelativeFileHashes $skillRoot
        $lockedSkill = @($Lock.skills | Where-Object { $_.name -eq $name } | Select-Object -First 1)

        if ($lockedSkill.Count -eq 0) {
            $violations += [ordered]@{
                skill = $name
                type = "missing-skill"
                path = $null
                message = "Skill is not present in skills-lock.json."
            }
            continue
        }

        $lockedManifest = Convert-LockFilesToManifest $lockedSkill[0].files
        $comparison = Compare-Manifests $lockedManifest $sourceManifest

        foreach ($path in $comparison.missingFiles) {
            $violations += [ordered]@{
                skill = $name
                type = "missing-file"
                path = $path
                message = "skills-lock.json contains a file that is missing from source."
            }
        }
        foreach ($path in $comparison.extraFiles) {
            $violations += [ordered]@{
                skill = $name
                type = "unlocked-file"
                path = $path
                message = "Source file exists but is not present in skills-lock.json."
            }
        }
        foreach ($path in $comparison.hashMismatches) {
            $violations += [ordered]@{
                skill = $name
                type = "hash-mismatch"
                path = $path
                expected = $lockedManifest[$path]
                actual = $sourceManifest[$path]
                message = "Source file hash does not match skills-lock.json."
            }
        }

        $bundleHash = Get-ManifestBundleHash $sourceManifest
        if ($lockedSkill[0].bundleSha256 -ne $bundleHash) {
            $violations += [ordered]@{
                skill = $name
                type = "bundle-hash-mismatch"
                path = $null
                expected = $lockedSkill[0].bundleSha256
                actual = $bundleHash
                message = "Skill bundle hash does not match skills-lock.json."
            }
        }
    }

    return [ordered]@{
        verified = ($violations.Count -eq 0)
        violations = $violations
    }
}

function Invoke-SkillScan($ScriptPath, $Root) {
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        return [ordered]@{
            success = $false
            skipped = $false
            exitCode = $null
            findings = @([ordered]@{
                    severity = "critical"
                    rule = "missing-scan-script"
                    file = $ScriptPath
                    line = 0
                    message = "scan_skills.ps1 is required before syncing."
                })
            output = ""
        }
    }

    $psExe = (Get-Process -Id $PID).Path
    $output = & $psExe -NoProfile -File $ScriptPath -SourceRoot $Root -Json 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output -join "`n")
    $parsed = $null
    try {
        $parsed = $text | ConvertFrom-Json
    } catch {
        return [ordered]@{
            success = $false
            skipped = $false
            exitCode = $exitCode
            findings = @([ordered]@{
                    severity = "critical"
                    rule = "scan-output-invalid"
                    file = $ScriptPath
                    line = 0
                    message = "scan_skills.ps1 did not return valid JSON."
                })
            output = $text
        }
    }

    return [ordered]@{
        success = ($exitCode -eq 0 -and $parsed.success -eq $true)
        skipped = $false
        exitCode = $exitCode
        findings = @($parsed.findings)
        output = $text
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

$allSkillNames = @(Get-ChildItem -LiteralPath $sourceSkillsRoot -Directory -Force | Select-Object -ExpandProperty Name | Sort-Object)
if ($SkillName.Count -eq 0) {
    $SkillName = $allSkillNames
}

$lockPath = Join-Path $sourceRootFull "skills-lock.json"
$scanScript = Join-Path $PSScriptRoot "scan_skills.ps1"
$lockUpdated = $false
$lockVerified = $false
$lockViolations = @()
$skillResults = @()
$tamperReports = @()
$testResults = @()

if ($SkipScan) {
    $scanResult = [ordered]@{
        success = $true
        skipped = $true
        exitCode = $null
        findings = @()
        output = ""
    }
} else {
    $scanResult = Invoke-SkillScan $scanScript $sourceRootFull
}

$preflightSucceeded = $scanResult.success -eq $true

if ($preflightSucceeded -and $UpdateLock) {
    $lock = New-SkillsLock $sourceSkillsRoot $allSkillNames
    $lock | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $lockPath -Encoding UTF8
    $lockUpdated = $true
}

if ($SkipLock) {
    $lockVerified = $false
} elseif ($preflightSucceeded) {
    $lock = $null
    if (Test-Path -LiteralPath $lockPath) {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    }
    $lockCheck = Test-SkillsLock $sourceSkillsRoot $lock $allSkillNames
    $lockVerified = $lockCheck.verified
    $lockViolations = @($lockCheck.violations)
    if (-not $lockVerified) {
        $preflightSucceeded = $false
    }
}

if ($preflightSucceeded) {
    foreach ($name in $SkillName) {
        $sourceSkill = Join-Path $sourceSkillsRoot $name
        if (-not (Test-Path -LiteralPath $sourceSkill)) {
            throw "Source skill not found: $sourceSkill"
        }

        $targetSkill = Join-Path $destinationRoot $name
        Assert-ChildPath $destinationRoot $targetSkill

        $sourceManifest = Get-RelativeFileHashes $sourceSkill
        $targetExists = Test-Path -LiteralPath $targetSkill
        $tamperReport = [ordered]@{
            name = $name
            targetExists = $targetExists
            addedFiles = @()
            removedFiles = @()
            changedFiles = @()
            tampered = $false
        }

        if ($targetExists) {
            $installedManifest = Get-RelativeFileHashes $targetSkill
            $tamperComparison = Compare-Manifests $sourceManifest $installedManifest
            $tamperReport.addedFiles = $tamperComparison.extraFiles
            $tamperReport.removedFiles = $tamperComparison.missingFiles
            $tamperReport.changedFiles = $tamperComparison.hashMismatches
            $tamperReport.tampered = -not $tamperComparison.hashesMatch
            Remove-Item -LiteralPath $targetSkill -Recurse -Force
        }
        $tamperReports += $tamperReport

        Copy-Item -LiteralPath $sourceSkill -Destination $destinationRoot -Recurse -Force

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

    if (-not $SkipTests) {
        $installedAuditScripts = Join-Path $destinationRoot "codex-setup-audit\scripts"
        $testResults += Invoke-InstalledTest "installed setup-audit self test" (Join-Path $installedAuditScripts "self_test.ps1") @("-Path", $SourceRoot)
        $testResults += Invoke-InstalledTest "installed setup-audit fixture test" (Join-Path $installedAuditScripts "fixture_test.ps1") @()
    }
}

$success = $preflightSucceeded -and
    (@($skillResults | Where-Object { -not $_.copied -or -not $_.hashesMatch }).Count -eq 0) -and
    ($SkipTests -or @($testResults | Where-Object { -not $_.passed }).Count -eq 0)

$result = [ordered]@{
    success = $success
    sourceRoot = $sourceRootFull
    destination = $destinationRoot
    scan = $scanResult
    lockPath = $lockPath
    lockSkipped = [bool]$SkipLock
    lockUpdated = $lockUpdated
    lockVerified = $lockVerified
    lockViolations = $lockViolations
    tamperReports = $tamperReports
    skills = $skillResults
    testsSkipped = [bool]$SkipTests
    tests = $testResults
}

if ($Json) {
    $result | ConvertTo-Json -Depth 12
} else {
    if ($success) {
        Write-Output "Skill sync succeeded."
    } else {
        Write-Output "Skill sync failed."
    }
    Write-Output "Source: $($result.sourceRoot)"
    Write-Output "Destination: $($result.destination)"
    Write-Output "Scan: success=$($result.scan.success), skipped=$($result.scan.skipped), findings=$(@($result.scan.findings).Count)"
    Write-Output "Lock: verified=$($result.lockVerified), updated=$($result.lockUpdated), skipped=$($result.lockSkipped), violations=$(@($result.lockViolations).Count)"
    foreach ($skill in $skillResults) {
        Write-Output "- $($skill.name): copied=$($skill.copied), hashesMatch=$($skill.hashesMatch), files=$($skill.destinationFileCount)"
    }
    foreach ($report in $tamperReports | Where-Object { $_.tampered }) {
        Write-Output "- $($report.name): installed tamper detected before overwrite"
    }
    foreach ($test in $testResults) {
        Write-Output "- $($test.name): passed=$($test.passed), exitCode=$($test.exitCode)"
    }
}

if (-not $success) { exit 1 }
