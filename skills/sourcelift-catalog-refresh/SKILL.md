---
name: sourcelift-catalog-refresh
description: Use when working on SourceLift, Great Homes Source, supplier/source catalog cleanup, Moorizon-style spreadsheets, quote-ready line sheets, pricing/margin review, catalog exports, or catalog UI QA.
---

# SourceLift Catalog Refresh

## Purpose

Handle the SourceLift/Great Homes Source workflow safely: messy supplier/source material becomes a canonical catalog, pricing review, line-sheet/export output, and local UI proof.

## Safety Rules

- Treat raw source files as immutable unless the user explicitly asks to edit them.
- Preserve provenance: distinguish raw input, cleaned canonical data, generated exports, and UI presentation.
- Do not overwrite generated outputs casually when the worktree is dirty. Inspect status first and explain what will change.
- Keep competitor scraping, SaaS MCPs, and scheduled refreshes out of the workflow until the user confirms a real source cadence.
- For Excel/workbook work, prefer structured spreadsheet tools or Python libraries over ad hoc text parsing.

## Workflow

1. Read the repo context first:
   - `README.md`
   - `_knowledge_base/plan-source-price-platform-v5-20260510.md` if present
   - current `git status --short --branch`
2. Identify the source file, generated workbook, catalog JSON, and UI files.
3. Before edits, state whether the task affects raw inputs, generation code, generated outputs, or UI.
4. For refresh/build work, use the repo command from README:

```powershell
& 'C:\Users\great\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' scripts\build_catalog.py
```

5. Verify the result:
   - build command exits 0
   - `app/data/catalog.json` exists and is valid JSON
   - `outputs/great_homes_source_catalog.xlsx` exists when expected
   - if UI changed, inspect `app/index.html`, `app/app.js`, `app/styles.css`, then use Browser for visual QA when practical
6. Report changes as source-safe categories:
   - raw input untouched
   - generation logic changed
   - generated data refreshed
   - UI changed
   - risks or manual review needed

## Good Defaults

- Prefer small, reversible changes to `scripts/build_catalog.py` or UI files.
- Keep line-sheet/export quality tied to the first offer: source health, clean product master, designer-ready line sheet, quote list, issue report, reusable import template.
- Check pricing/margin fields for missing cost, outliers, duplicate SKUs, image gaps, category problems, and quote-safe status.
- When unsure whether a file is raw or generated, stop and classify it before editing.

## Avoid

- Do not turn this repo into a full PIM or SaaS backend prematurely.
- Do not add recurring automation before there is a real supplier refresh cadence.
- Do not add broad MCP servers just because they exist.
- Do not run browser or catalog builds from lifecycle hooks on every prompt.
