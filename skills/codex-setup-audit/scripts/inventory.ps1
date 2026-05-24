param(
    [string]$Path = (Get-Location).Path,
    [int]$MaxFiles = 5000
)

$ErrorActionPreference = "SilentlyContinue"

function Test-Command($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Read-Text($LiteralPath, $MaxChars = 20000) {
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return $null }
    $text = Get-Content -LiteralPath $LiteralPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { return $null }
    if ($text.Length -gt $MaxChars) { return $text.Substring(0, $MaxChars) }
    return $text
}

function Get-RelativePathSafe($Base, $FullName) {
    try {
        $baseFull = [System.IO.Path]::GetFullPath($Base).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        $targetFull = [System.IO.Path]::GetFullPath($FullName)
        $baseUri = [System.Uri]::new($baseFull)
        $targetUri = [System.Uri]::new($targetFull)
        $relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
        return $relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    } catch {
        return $FullName
    }
}

$root = (Resolve-Path -LiteralPath $Path).Path
Push-Location $root

$git = @{
    isRepo = $false
    root = $null
    branch = $null
    remotes = @()
    statusShort = @()
}

if (Test-Command git) {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitRoot) {
        $git.isRepo = $true
        $git.root = $gitRoot.Trim()
        $git.branch = (git branch --show-current 2>$null).Trim()
        $git.remotes = @(git remote -v 2>$null | Select-Object -First 20)
        $git.statusShort = @(git status --short --branch 2>$null | Select-Object -First 100)
    }
}

$files = @()
if (Test-Command rg) {
    $files = @(rg --files 2>$null | Select-Object -First $MaxFiles)
} else {
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch "\\.git\\" } |
        Select-Object -First $MaxFiles |
        ForEach-Object { Get-RelativePathSafe $root $_.FullName })
}

$extensionCounts = @{}
foreach ($file in $files) {
    $ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = "(none)" }
    if (-not $extensionCounts.ContainsKey($ext)) { $extensionCounts[$ext] = 0 }
    $extensionCounts[$ext] += 1
}

$importantNames = @(
    "README.md", "README", "AGENTS.md", "CLAUDE.md", "package.json",
    "pnpm-lock.yaml", "yarn.lock", "package-lock.json", "pyproject.toml",
    "requirements.txt", "uv.lock", "poetry.lock", "Pipfile", "go.mod",
    "Cargo.toml", "Dockerfile", "docker-compose.yml", "compose.yml",
    "Makefile", "justfile", "tsconfig.json", "vite.config.ts",
    "next.config.js", "next.config.mjs"
)

$importantFiles = @()
foreach ($name in $importantNames) {
    $matches = $files | Where-Object { $_ -ieq $name -or $_ -ilike "*/$name" -or $_ -ilike "*\$name" }
    $importantFiles += $matches
}
$importantFiles = @($importantFiles | Select-Object -Unique)

$ciFiles = @($files | Where-Object {
    $_ -like ".github/workflows/*" -or $_ -like ".gitlab-ci*" -or $_ -like "azure-pipelines*" -or $_ -like "Jenkinsfile"
})

$testFiles = @($files | Where-Object {
    $_ -match "(^|[\\/])(test|tests|spec|__tests__)[\\/]" -or
    $_ -match "(test|spec)\.(js|jsx|ts|tsx|py|go|rs|cs)$" -or
    $_ -match "(^|[\\/])[^\\/]*(test|spec)[^\\/]*\.(ps1|psm1)$"
} | Select-Object -First 200)

$docsFiles = @($files | Where-Object {
    $_ -like "docs/*" -or $_ -like "_knowledge_base/*" -or $_ -match "(ADR|architecture|plan|runbook|playbook|decision).*\.md$"
} | Select-Object -First 200)

$codexHome = Join-Path $env:USERPROFILE ".codex"
$codexConfig = Join-Path $codexHome "config.toml"
$codexConfigText = Read-Text $codexConfig
$codexSkills = @()
$codexPlugins = @()
if (Test-Path -LiteralPath (Join-Path $codexHome "skills")) {
    $codexSkills = @(Get-ChildItem -LiteralPath (Join-Path $codexHome "skills") -Directory -Force |
        Where-Object { $_.Name -ne ".system" } |
        Select-Object -ExpandProperty Name)
}
if (Test-Path -LiteralPath (Join-Path $codexHome "plugins/cache")) {
    $codexPlugins = @(Get-ChildItem -LiteralPath (Join-Path $codexHome "plugins/cache") -Directory -Force |
        Select-Object -ExpandProperty Name)
}

$configSignals = @{
    hasConfig = [bool]$codexConfigText
    features = @()
    pluginSections = @()
    mcpMentions = @()
    hookStateMentions = 0
}
if ($codexConfigText) {
    $configSignals.features = @($codexConfigText -split "`n" | Where-Object {
        $_ -match "^\s*(hooks|plugin_hooks|goals|plugins|browser_use|computer_use)\s*="
    } | ForEach-Object { $_.Trim() })
    $configSignals.pluginSections = @($codexConfigText -split "`n" | Where-Object {
        $_ -match "^\[plugins\."
    } | ForEach-Object { $_.Trim() })
    $configSignals.mcpMentions = @($codexConfigText -split "`n" | Where-Object {
        $_ -match "mcp|servers"
    } | Select-Object -First 40 | ForEach-Object { $_.Trim() })
    $configSignals.hookStateMentions = @($codexConfigText -split "`n" | Where-Object {
        $_ -match "^\[hooks\.state"
    }).Count
}

$manifestSignals = @{
    javascript = @("package.json", "pnpm-lock.yaml", "yarn.lock", "package-lock.json") | Where-Object { $files -contains $_ }
    python = @("pyproject.toml", "requirements.txt", "uv.lock", "poetry.lock", "Pipfile") | Where-Object { $files -contains $_ }
    dotnet = @($files | Where-Object { $_ -match "\.(sln|csproj)$" })
    go = @("go.mod") | Where-Object { $files -contains $_ }
    rust = @("Cargo.toml") | Where-Object { $files -contains $_ }
    docker = @("Dockerfile", "docker-compose.yml", "compose.yml") | Where-Object { $files -contains $_ }
}

$result = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    root = $root
    git = $git
    counts = @{
        filesSampled = $files.Count
        extensionCounts = $extensionCounts
    }
    manifests = $manifestSignals
    importantFiles = $importantFiles
    ciFiles = $ciFiles
    testFiles = $testFiles
    docsFiles = $docsFiles
    codex = @{
        home = $codexHome
        config = $codexConfig
        configSignals = $configSignals
        skills = $codexSkills
        pluginCacheRoots = $codexPlugins
    }
}

Pop-Location
$result | ConvertTo-Json -Depth 8
