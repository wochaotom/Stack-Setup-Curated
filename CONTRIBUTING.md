# Contributing

This repository is a curated Codex skill bundle. Keep changes small, evidence
backed, and easy to review.

## Source Of Truth

- Edit `skills/` in this repo first.
- Treat installed copies under `C:\Users\<you>\.codex\skills` as derived
  artifacts.
- Do not edit plugin cache paths or installed skill directories as the canonical
  source.

## Skill Changes

After changing any skill file:

```powershell
& .\scripts\sync_skills.ps1 -UpdateLock
& .\scripts\scan_skills.ps1
& .\scripts\harness_test.ps1
```

After changing `skills/codex-setup-audit`, also run:

```powershell
& .\skills\codex-setup-audit\scripts\self_test.ps1 -Path (Get-Location)
& .\skills\codex-setup-audit\scripts\fixture_test.ps1
```

Before committing:

```powershell
& .\scripts\sync_skills.ps1
git diff --check
git status --short
```

## Source Policy

- Use official or first-party docs for platform adapter claims.
- Treat community directories as discovery-only.
- Do not promote `officialskills.sh` or unofficial mirrors as vetted sources.
- Pin third-party skills to a commit or version when possible.

## Pull Request Checklist

- [ ] The change is scoped to the stated behavior.
- [ ] Skill edits include a refreshed `skills-lock.json`.
- [ ] Scanner, harness, self, fixture, and sync checks pass where applicable.
- [ ] New platform/source claims cite official sources.
- [ ] Converter changes preserve the blocked/nonzero exit contract for lossy or
      unsupported conversions.
