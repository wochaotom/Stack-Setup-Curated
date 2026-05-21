param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditPath = Join-Path $scriptDir "audit.ps1"
$tmpRoot = Join-Path $env:TEMP ("codex-setup-audit-fixtures-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

function Write-FixtureFile($Path, $Text) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8
}

function Add-Check($Name, $Pass, $Detail = "") {
    $script:checks += [ordered]@{
        name = $Name
        pass = [bool]$Pass
        detail = $Detail
    }
}

$checks = @()

try {
    $reactRoot = Join-Path $tmpRoot "react-app"
    Write-FixtureFile (Join-Path $reactRoot "README.md") "# React App`nA small UI app."
    Write-FixtureFile (Join-Path $reactRoot "package.json") @'
{
  "scripts": {
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "react": "^19.0.0",
    "next": "^16.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "eslint": "^9.0.0",
    "vitest": "^4.0.0"
  }
}
'@
    Write-FixtureFile (Join-Path $reactRoot "tsconfig.json") "{}"
    Write-FixtureFile (Join-Path $reactRoot "src\App.tsx") "export function App() { return <main /> }"

    $pyRoot = Join-Path $tmpRoot "python-service"
    Write-FixtureFile (Join-Path $pyRoot "README.md") "# Python Service`nA small API service."
    Write-FixtureFile (Join-Path $pyRoot "pyproject.toml") @'
[tool.ruff]
line-length = 100

[tool.pytest.ini_options]
testpaths = ["tests"]
'@
    Write-FixtureFile (Join-Path $pyRoot "service.py") "def ok(): return True"
    Write-FixtureFile (Join-Path $pyRoot "tests\test_service.py") "def test_ok(): assert True"

    $reactAudit = & $auditPath -Path $reactRoot
    $pyAudit = & $auditPath -Path $pyRoot

    Add-Check "react browser recommendation" ($reactAudit -match "Use Browser")
    Add-Check "react docs mcp gated" ($reactAudit -match "versioned docs" -and $reactAudit -match "narrow docs MCP")
    Add-Check "react quality hooks gated" ($reactAudit -match "JavaScript quality hooks" -and $reactAudit -match "fast and stable")
    Add-Check "react model fit and discussion" ($reactAudit -match "Model fit:" -and $reactAudit -match "Model Plan" -and $reactAudit -match "Which workflow hurts most today")
    Add-Check "react fit evidence emitted" ($reactAudit -match " Fit: " -and $reactAudit -notmatch "Fit: Frontend dependencies were detected")
    Add-Check "python quality hooks gated" ($pyAudit -match "Ruff/pytest hooks" -and $pyAudit -match "command timing")
    Add-Check "python setup plan emitted" ($pyAudit -match "Discuss Before Installing" -and $pyAudit -match "Verify Setup")
    Add-Check "fixtures stay non-sourcelift" ($reactAudit -notmatch "SourceLift" -and $pyAudit -notmatch "SourceLift")

    $failed = @($checks | Where-Object { -not $_.pass })
    [ordered]@{
        passed = @($checks | Where-Object { $_.pass }).Count
        failed = $failed.Count
        checks = $checks
    } | ConvertTo-Json -Depth 5

    if ($failed.Count -gt 0) { exit 1 }
} finally {
    if (Test-Path -LiteralPath $tmpRoot) {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force
    }
}
