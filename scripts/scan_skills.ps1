param(
    [string]$SourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function New-Finding($Severity, $Rule, $File, $Line, $Message) {
    return [ordered]@{
        severity = $Severity
        rule = $Rule
        file = $File
        line = $Line
        message = $Message
    }
}

$sourceRootFull = [System.IO.Path]::GetFullPath($SourceRoot)
$skillsRoot = Join-Path $sourceRootFull "skills"
$findings = @()

function Get-RelativePathCompat($BasePath, $FullPath) {
    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $targetFull = [System.IO.Path]::GetFullPath($FullPath)
    $baseUri = [System.Uri]::new($baseFull)
    $targetUri = [System.Uri]::new($targetFull)
    $relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
    return $relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
}

if (-not (Test-Path -LiteralPath $skillsRoot)) {
    $findings += New-Finding "critical" "missing-skills-directory" "skills" 0 "Source root does not contain a skills directory."
} else {
    $files = @(Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Force | Sort-Object FullName)
    foreach ($file in $files) {
        $relative = Get-RelativePathCompat $sourceRootFull $file.FullName
        $extension = $file.Extension.ToLowerInvariant()
        $isPowerShell = $extension -in @(".ps1", ".psm1", ".psd1")
        $isSkillEntrypoint = $file.Name -eq "SKILL.md"
        $shouldScanText = $isPowerShell -or $isSkillEntrypoint -or ($extension -in @(".md", ".json", ".yml", ".yaml"))

        if (-not $shouldScanText) {
            continue
        }

        $lines = @(Get-Content -LiteralPath $file.FullName)
        for ($index = 0; $index -lt $lines.Count; $index++) {
            $lineNumber = $index + 1
            $line = $lines[$index]

            if ($isSkillEntrypoint -and $line -match "(?i)\b(ignore|disregard)\s+(all\s+)?(previous|prior|system|developer)\s+instructions\b") {
                $findings += New-Finding "critical" "prompt-injection-directive" $relative $lineNumber "Skill entrypoint contains a direct instruction-hijacking phrase."
            }

            if ($isPowerShell -and $line -match "(?i)\b(Invoke-Expression|iex)\b") {
                $findings += New-Finding "critical" "powershell-dynamic-execution" $relative $lineNumber "PowerShell dynamic execution is not allowed in bundled skills."
            }

            if ($isPowerShell -and $line -match "(?i)\b(curl|Invoke-WebRequest|iwr|wget)\b.*\|\s*(Invoke-Expression|iex|sh|bash)\b") {
                $findings += New-Finding "critical" "fetch-and-execute" $relative $lineNumber "Fetched code must not be piped into an interpreter."
            }

            if ($line -match "(?i)\b(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{40,})\b") {
                $findings += New-Finding "critical" "secret-literal" $relative $lineNumber "File appears to contain a live credential-shaped secret."
            }
        }
    }
}

$criticalCount = @($findings | Where-Object { $_.severity -eq "critical" }).Count
$result = [ordered]@{
    success = ($criticalCount -eq 0)
    sourceRoot = $sourceRootFull
    scannedRoot = $skillsRoot
    findings = $findings
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    if ($result.success) {
        Write-Output "Skill scan succeeded."
    } else {
        Write-Output "Skill scan failed."
    }
    foreach ($finding in $findings) {
        Write-Output "- [$($finding.severity)] $($finding.rule) $($finding.file):$($finding.line) $($finding.message)"
    }
}

if (-not $result.success) { exit 1 }
