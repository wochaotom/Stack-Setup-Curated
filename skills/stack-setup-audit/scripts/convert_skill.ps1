param(
    [string]$SourcePath,
    [string]$Target,
    [string]$OutputPath = (Join-Path (Get-Location).Path "converted-agent-artifact"),
    [switch]$AllowPartial,
    [switch]$Json,
    [switch]$ListTargets
)

$ErrorActionPreference = "Stop"

function Join-PathParts($BasePath, $Parts) {
    $path = $BasePath
    foreach ($part in @($Parts)) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        $path = Join-Path $path $part
    }
    return $path
}

function Get-FullPath($Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-ChildPath($RootPath, $ChildPath) {
    $rootFull = (Get-FullPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $childFull = Get-FullPath $ChildPath
    $rootWithSlash = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    if (($childFull -ne $rootFull) -and (-not $childFull.StartsWith($rootWithSlash, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing to write outside output root: $childFull"
    }
}

function ConvertTo-SafeName($Name) {
    $value = ([string]$Name).Trim().ToLowerInvariant()
    $value = $value -replace "[^a-z0-9]+", "-"
    $value = $value -replace "-+", "-"
    return $value.Trim("-")
}

function Read-SkillMetadata($SkillPath) {
    $skillFile = Join-Path $SkillPath "SKILL.md"
    $text = Get-Content -LiteralPath $skillFile -Raw
    $name = ""
    $description = ""

    if ($text -match "(?ms)^---\s*(.*?)\s*---") {
        $frontmatter = $matches[1]
        foreach ($line in ($frontmatter -split "`r?`n")) {
            if (-not $name -and $line -match "^\s*name\s*:\s*['""]?([^'""]+)['""]?\s*$") {
                $name = $matches[1].Trim()
            }
            if (-not $description -and $line -match "^\s*description\s*:\s*['""]?([^'""]+)['""]?\s*$") {
                $description = $matches[1].Trim()
            }
        }
    }

    if (-not $name) {
        $name = Split-Path -Leaf $SkillPath
    }
    $safeName = ConvertTo-SafeName $name
    if (-not $description) {
        $description = "Converted skill from $safeName."
    }

    $supportingFiles = @(
        Get-ChildItem -LiteralPath $SkillPath -Recurse -File -Force |
            Where-Object { $_.Name -ne "SKILL.md" }
    )
    $supportingDirs = @(
        Get-ChildItem -LiteralPath $SkillPath -Directory -Force |
            Select-Object -ExpandProperty Name
    )

    return [ordered]@{
        path = (Get-FullPath $SkillPath)
        skillFile = (Get-FullPath $skillFile)
        name = $safeName
        originalName = $name
        description = $description
        text = $text
        supportingFileCount = $supportingFiles.Count
        supportingDirs = @($supportingDirs)
        hasSupportingFiles = ($supportingFiles.Count -gt 0)
        isValidName = ($safeName -match "^[a-z0-9]+(-[a-z0-9]+)*$" -and $safeName -eq $name)
    }
}

function Get-TargetAdapter($TargetName) {
    switch (([string]$TargetName).ToLowerInvariant()) {
        "codex" {
            return [ordered]@{ key = "codex"; label = "Codex"; kind = "native-skill"; root = @("skills"); extension = ""; supportsSupportingFiles = $true; source = "https://github.com/openai/skills" }
        }
        "claude" {
            return Get-TargetAdapter "claude-code"
        }
        "claude-code" {
            return [ordered]@{ key = "claude-code"; label = "Claude Code"; kind = "native-skill"; root = @(".claude", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://docs.claude.com/en/docs/claude-code" }
        }
        "github" {
            return Get-TargetAdapter "github-copilot"
        }
        "github-copilot" {
            return [ordered]@{ key = "github-copilot"; label = "GitHub Copilot"; kind = "native-skill"; root = @(".github", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://docs.github.com/en/copilot/concepts/agents/about-agent-skills" }
        }
        "cursor" {
            return [ordered]@{ key = "cursor"; label = "Cursor"; kind = "native-skill"; root = @(".cursor", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://cursor.com/docs/skills" }
        }
        "antigravity" {
            return Get-TargetAdapter "google-antigravity"
        }
        "google-antigravity" {
            return [ordered]@{ key = "google-antigravity"; label = "Google Antigravity"; kind = "native-skill"; root = @(".agents", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://www.antigravity.google/docs/plugins" }
        }
        "gemini" {
            return Get-TargetAdapter "gemini-cli"
        }
        "gemini-cli" {
            return [ordered]@{ key = "gemini-cli"; label = "Gemini CLI"; kind = "native-skill"; root = @(".gemini", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://google-gemini.github.io/gemini-cli/docs/" }
        }
        "opencode" {
            return [ordered]@{ key = "opencode"; label = "OpenCode"; kind = "native-skill"; root = @(".opencode", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://opencode.ai/docs/skills/" }
        }
        "cline" {
            return [ordered]@{ key = "cline"; label = "Cline"; kind = "native-skill"; root = @(".cline", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://docs.cline.bot/customization/skills" }
        }
        "windsurf" {
            return [ordered]@{ key = "windsurf"; label = "Windsurf"; kind = "native-skill"; root = @(".windsurf", "skills"); extension = ""; supportsSupportingFiles = $true; source = "https://docs.windsurf.com/windsurf/cascade/skills" }
        }
        "aider" {
            return [ordered]@{ key = "aider"; label = "Aider"; kind = "instruction-file"; root = @(); extension = ".md"; supportsSupportingFiles = $false; source = "https://aider.chat/docs/" }
        }
        "continue" {
            return [ordered]@{ key = "continue"; label = "Continue"; kind = "instruction-file"; root = @(".continue", "checks"); extension = ".md"; supportsSupportingFiles = $false; source = "https://docs.continue.dev/" }
        }
        "roo" {
            return Get-TargetAdapter "roo-code"
        }
        "roo-code" {
            return [ordered]@{ key = "roo-code"; label = "Roo Code"; kind = "instruction-file"; root = @(".roo", "rules"); extension = ".md"; supportsSupportingFiles = $false; source = "https://docs.roocode.com/" }
        }
        default {
            return $null
        }
    }
}

function Get-AllAdapters() {
    return @(
        "codex",
        "claude-code",
        "github-copilot",
        "cursor",
        "google-antigravity",
        "gemini-cli",
        "opencode",
        "cline",
        "windsurf",
        "aider",
        "continue",
        "roo-code"
    ) | ForEach-Object { Get-TargetAdapter $_ }
}

function New-Result($Success, $Status, $TargetAdapter, $SourceKind, $SourceName, $GeneratedFiles, $Reason, $Native, $Lossy, $RequiresManualReview) {
    return [ordered]@{
        success = [bool]$Success
        status = $Status
        target = if ($TargetAdapter) { $TargetAdapter.key } else { $Target }
        targetLabel = if ($TargetAdapter) { $TargetAdapter.label } else { $Target }
        sourceKind = $SourceKind
        sourceName = $SourceName
        generatedFiles = @($GeneratedFiles)
        reason = $Reason
        sourceAuthority = if ($TargetAdapter) {
            [ordered]@{
                status = "official"
                sources = @($TargetAdapter.source)
            }
        } else {
            [ordered]@{
                status = "unknown"
                sources = @()
            }
        }
        conversion = [ordered]@{
            native = [bool]$Native
            lossy = [bool]$Lossy
            requiresManualReview = [bool]$RequiresManualReview
        }
    }
}

function Write-Result($Result) {
    if ($Json) {
        $Result | ConvertTo-Json -Depth 8
        return
    }

    Write-Output "$($Result.status): $($Result.reason)"
    foreach ($file in @($Result.generatedFiles)) {
        Write-Output "- $file"
    }
}

function Complete-Result($Result) {
    Write-Result $Result
    if (-not $Result.success) {
        exit 1
    }
}

function Write-InstructionFile($Skill, $TargetAdapter, $OutputRoot) {
    if ($Skill.hasSupportingFiles -and -not $AllowPartial) {
        return New-Result $false "blocked" $TargetAdapter "skill" $Skill.name @() "Target $($TargetAdapter.label) does not have a native skill folder adapter here; conversion would drop supporting files. Re-run with -AllowPartial only after manual review." $false $true $true
    }

    $root = Join-PathParts $OutputRoot $TargetAdapter.root
    if ($TargetAdapter.key -eq "aider") {
        $filePath = Join-Path $root ("CONVENTIONS." + $Skill.name + ".md")
    } else {
        $filePath = Join-Path $root ($Skill.name + $TargetAdapter.extension)
    }
    Assert-ChildPath $OutputRoot $filePath

    $directory = Split-Path -Parent $filePath
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $content = @(
        "---",
        "name: $($Skill.name)",
        "description: $($Skill.description)",
        "converted-from: Agent Skill",
        "target: $($TargetAdapter.label)",
        "source-authority: $($TargetAdapter.source)",
        "---",
        "",
        "# $($Skill.name)",
        "",
        "This is an instruction-only conversion of an Agent Skill for $($TargetAdapter.label). Review it before relying on it because this target does not preserve bundled resources automatically.",
        "",
        $Skill.text
    ) -join "`r`n"

    Set-Content -LiteralPath $filePath -Encoding UTF8 -Value $content
    return New-Result $true "converted" $TargetAdapter "skill" $Skill.name @((Get-FullPath $filePath)) "Converted to an instruction-only artifact for $($TargetAdapter.label)." $false $true $true
}

function Copy-NativeSkill($Skill, $TargetAdapter, $OutputRoot) {
    if (-not $Skill.isValidName) {
        return New-Result $false "blocked" $TargetAdapter "skill" $Skill.name @() "Skill name '$($Skill.originalName)' is not portable. Use lowercase kebab-case and keep the directory name aligned with the SKILL.md name." $true $false $true
    }

    $targetRoot = Join-PathParts $OutputRoot $TargetAdapter.root
    $targetPath = Join-Path $targetRoot $Skill.name
    Assert-ChildPath $OutputRoot $targetPath

    New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }
    Copy-Item -LiteralPath $Skill.path -Destination $targetPath -Recurse -Force

    $generated = @(
        Get-ChildItem -LiteralPath $targetPath -Recurse -File -Force |
            Sort-Object FullName |
            ForEach-Object { Get-FullPath $_.FullName }
    )
    return New-Result $true "converted" $TargetAdapter "skill" $Skill.name $generated "Copied native Agent Skill folder for $($TargetAdapter.label)." $true $false $false
}

function Convert-OneSkill($SkillPath, $TargetAdapter, $OutputRoot) {
    $skill = Read-SkillMetadata $SkillPath
    if ($TargetAdapter.kind -eq "native-skill") {
        return Copy-NativeSkill $skill $TargetAdapter $OutputRoot
    }
    return Write-InstructionFile $skill $TargetAdapter $OutputRoot
}

function Get-PluginSkillPaths($PluginPath) {
    $skillsRoot = Join-Path $PluginPath "skills"
    if (-not (Test-Path -LiteralPath $skillsRoot)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $skillsRoot -Directory -Force |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") } |
            Select-Object -ExpandProperty FullName
    )
}

function Test-PluginIsPureSkillBundle($PluginPath) {
    $allowedFiles = @("plugin.json", "README.md", "README", "LICENSE", "LICENSE.md", "LICENSE.txt")
    $allowedDirs = @("skills", ".codex-plugin")
    $unsupported = @()

    foreach ($item in Get-ChildItem -LiteralPath $PluginPath -Force) {
        if ($item.PSIsContainer) {
            if ($allowedDirs -notcontains $item.Name) { $unsupported += $item.Name }
        } else {
            if ($allowedFiles -notcontains $item.Name) { $unsupported += $item.Name }
        }
    }

    $codexPluginDir = Join-Path $PluginPath ".codex-plugin"
    if (Test-Path -LiteralPath $codexPluginDir) {
        foreach ($item in Get-ChildItem -LiteralPath $codexPluginDir -Force) {
            if ($item.PSIsContainer -or $item.Name -ne "plugin.json") {
                $unsupported += ".codex-plugin/$($item.Name)"
            }
        }
    }

    return [ordered]@{
        isPure = ($unsupported.Count -eq 0)
        unsupported = @($unsupported)
    }
}

function Convert-Plugin($PluginPath, $TargetAdapter, $OutputRoot) {
    $pluginName = ConvertTo-SafeName (Split-Path -Leaf $PluginPath)
    $purity = Test-PluginIsPureSkillBundle $PluginPath
    $skillPaths = @(Get-PluginSkillPaths $PluginPath)

    if ($skillPaths.Count -eq 0) {
        return New-Result $false "blocked" $TargetAdapter "plugin" $pluginName @() "Plugin conversion is blocked because no portable skills/ subdirectories with SKILL.md were found." $false $true $true
    }
    if (-not $purity.isPure) {
        return New-Result $false "blocked" $TargetAdapter "plugin" $pluginName @() ("Plugin conversion is blocked because plugins can include tools, MCP, hooks, auth, or client-exclusive features. Unsupported entries: " + (@($purity.unsupported) -join ", ")) $false $true $true
    }

    $generated = @()
    foreach ($skillPath in $skillPaths) {
        $result = Convert-OneSkill $skillPath $TargetAdapter $OutputRoot
        if (-not $result.success) {
            return New-Result $false "blocked" $TargetAdapter "plugin" $pluginName $generated $result.reason $result.conversion.native $result.conversion.lossy $true
        }
        $generated += @($result.generatedFiles)
    }

    return New-Result $true "converted" $TargetAdapter "plugin" $pluginName $generated "Extracted portable skills from a pure skill-bundle plugin for $($TargetAdapter.label)." ($TargetAdapter.kind -eq "native-skill") ($TargetAdapter.kind -ne "native-skill") ($TargetAdapter.kind -ne "native-skill")
}

if ($ListTargets) {
    $targets = @(Get-AllAdapters | ForEach-Object {
        [ordered]@{
            target = $_.key
            label = $_.label
            kind = $_.kind
            preservesSupportingFiles = $_.supportsSupportingFiles
            sourceAuthority = [ordered]@{
                status = "official"
                sources = @($_.source)
            }
        }
    })
    if ($Json) {
        $targets | ConvertTo-Json -Depth 8
    } else {
        foreach ($adapter in $targets) {
            Write-Output "$($adapter.target) - $($adapter.kind) - $($adapter.sourceAuthority.sources -join ', ')"
        }
    }
    return
}

if (-not $SourcePath -or -not $Target) {
    $result = New-Result $false "blocked" $null "unknown" "" @() "SourcePath and Target are required unless -ListTargets is used." $false $true $true
    Complete-Result $result
    return
}

$adapter = Get-TargetAdapter $Target
if (-not $adapter) {
    $result = New-Result $false "unsupported" $null "unknown" "" @() "Unsupported target '$Target'. Use -ListTargets to inspect supported adapters." $false $true $true
    Complete-Result $result
    return
}

$sourceFull = Get-FullPath $SourcePath
if (-not (Test-Path -LiteralPath $sourceFull)) {
    $result = New-Result $false "blocked" $adapter "unknown" "" @() "Source path does not exist: $sourceFull" $false $true $true
    Complete-Result $result
    return
}

$outputFull = Get-FullPath $OutputPath
New-Item -ItemType Directory -Force -Path $outputFull | Out-Null

if (Test-Path -LiteralPath (Join-Path $sourceFull "SKILL.md")) {
    $result = Convert-OneSkill $sourceFull $adapter $outputFull
    Complete-Result $result
    return
}

$hasPluginManifest = (Test-Path -LiteralPath (Join-Path $sourceFull "plugin.json")) -or (Test-Path -LiteralPath (Join-Path $sourceFull ".codex-plugin\plugin.json"))
$hasPluginSkills = Test-Path -LiteralPath (Join-Path $sourceFull "skills")
if ($hasPluginManifest -or $hasPluginSkills) {
    $result = Convert-Plugin $sourceFull $adapter $outputFull
    Complete-Result $result
    return
}

$result = New-Result $false "blocked" $adapter "unknown" (Split-Path -Leaf $sourceFull) @() "Source is neither a direct Agent Skill nor a pure skill-bundle plugin." $false $true $true
Complete-Result $result
