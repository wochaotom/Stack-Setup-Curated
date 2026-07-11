# Security Policy

This repo contains agent skills and scripts that can influence how coding
agents read, write, verify, and sync local workspaces. Treat prompt-injection,
unsafe shell behavior, and supply-chain drift as security issues.

## Reportable Issues

Please report:

- prompt-injection directives inside bundled skills,
- descriptor-declared MCP/tools/hooks/commands/agents/auth/install surfaces that
  are hidden, misleading, or insufficiently reviewed,
- fetch-and-execute patterns,
- dynamic PowerShell execution,
- credential-shaped secrets in skills, docs, fixtures, or logs,
- converter path traversal or writes outside the requested output root,
- sync behavior that overwrites unexpected locations,
- false-success exits for blocked or unsupported conversions,
- platform adapter claims backed by unofficial or unsafe sources.

## Current Guardrails

Run:

```powershell
& .\scripts\scan_skills.ps1
& .\scripts\harness_test.ps1
& .\skills\stack-setup-audit\scripts\self_test.ps1 -Path (Get-Location)
& .\skills\stack-setup-audit\scripts\fixture_test.ps1
& .\scripts\sync_skills.ps1
```

The scanner rejects direct prompt-injection phrases, dynamic PowerShell
execution, fetch-and-execute pipelines, and credential-shaped secret literals in
bundled skills, descriptors, and docs. It also emits warnings for structured
descriptors that declare tool, permission, auth, install, telemetry, or runtime
surfaces requiring source review.

## Disclosure

There is no bounty program. If GitHub private security advisories are available
for this repository, use them. Otherwise, open a minimal public issue that does
not include live credentials, private paths, or exploit details beyond what is
needed to reproduce safely.
