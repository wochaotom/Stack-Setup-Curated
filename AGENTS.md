# Agent Instructions

This repository is a curated Codex skill bundle. Treat the files under `skills/`
as the source of truth.

## Skill Sync

- Installed copies under `C:\Users\great\.codex\skills` are derived artifacts.
- Prefer editing this repo first, then syncing to the installed skills directory.
- Do not treat installed cache or plugin paths as authoritative source.

## Verification

Run these checks after changing `skills/codex-setup-audit`:

```powershell
& .\skills\codex-setup-audit\scripts\self_test.ps1 -Path (Get-Location)
& .\skills\codex-setup-audit\scripts\fixture_test.ps1
```

## Audit Classification

- This repo should classify as a Codex skill bundle.
- Bundled skill names are inventory, not target-repo identity.
- SourceLift / Great Homes Source fit requires both domain text and catalog
  structure such as `scripts\build_catalog.py`, Excel inputs, catalog outputs,
  or the SourceLift plan file.

## Host Context

Codex config, plugins, hooks, and MCP tools are host-environment context. Keep
them separate from target-repo evidence when changing audit logic.
