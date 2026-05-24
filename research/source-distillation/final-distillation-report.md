# Final Distillation Report

## Verdict

Both repositories are valuable community marketplace sources, but neither is platform authority. They should be used for discovery, taxonomy, packaging patterns, scanner stress tests, and selective candidate review. They should not be bulk-installed, vendored, or treated as official Claude/Codex/Cursor/GitHub Copilot guidance.

Pinned sources:

- Cybersecurity: `mukul975/Anthropic-Cybersecurity-Skills@0f429d0f96ee70d2a6c259c4ecc6c6e18e0d23ff`.
- Privacy: `mukul975/Privacy-Data-Protection-Skills@9b2ef9eae161c00a17241d42a388571321b33e9f`.

No third-party scripts were executed. The review used static inspection of cloned snapshots and GitHub metadata.

## What We Extracted

- 47 taxonomy rows across cyber domains and privacy plugin domains.
- 40 reusable patterns tied to evidence.
- 20 risk controls and scanner-rule candidates.
- 25 candidate skills/plugins classified as `convert`, `link`, or `reject`.
- 16 conversion opportunities, including source-review patterns rather than vendored content.
- A verifier that computes `distillation_score` mechanically from the artifacts.

## Main Lessons

1. Popularity and install safety are different.
   Evidence: cyber has strong public signal but 1,032 scripts.

2. Clean structure is not enough.
   Evidence: privacy has segmented plugin bundles and SECURITY/CITATION metadata, but its domain is high-stakes and time-sensitive.

3. Marketplace sources can be legitimate sole-source candidates.
   Evidence: both repos contain domain-specific skills that may not exist natively elsewhere.

4. Adapter behavior still needs official platform docs.
   Evidence: both repos expose Claude plugin metadata, but that does not prove Codex, Cursor, Copilot, Windsurf, or Gemini behavior.

5. Script count must be visible before any install recommendation.
   Evidence: cyber has 1,032 script files; privacy has 824 script files.

6. Prompt-injection strings can be legitimate fixture data.
   Evidence: both repos contain defensive prompt-injection examples.

7. Compliance repositories need a freshness rule.
   Evidence: privacy `SECURITY.md` treats inaccurate regulatory citations as reportable.

## Recommended Source Classification

Cybersecurity repo:

- Source trust: B. High public signal, large corpus, good metadata.
- Install safety: C. Very high executable and offensive-domain surface.
- Best use: scanner stress tests, taxonomy, DFIR/security-operations concepts, link-only high-risk workflows.

Privacy repo:

- Source trust: B-. Structured and licensed, but smaller public signal and older push date.
- Install safety: B-. Cleaner quick scan than cyber, but high-stakes regulatory content.
- Best use: privacy engineering, data classification, candidate templates, packaging segmentation patterns.

## Prioritized Next Actions

1. Add source scorecards to setup-audit output for community marketplace candidates.
2. Add review-level scanner findings for fetch-execute snippets, offensive cyber terms, fixture prompt injection, and secret-shaped examples.
3. Add a no-third-party-script-execution invariant to source review.
4. Add marketplace source-path and declared-count checks.
5. Add duplicate package drift checks for repos that copy skills into plugin bundles.
6. Add legal/regulatory freshness fields for privacy/compliance sources.
7. Add classification output for candidate skills: keep, convert, link, reject.
8. Add optional source-index ingestion for repos that publish machine-readable indexes.
9. Add framework coverage output for sources with MITRE/NIST/regulatory mappings.
10. Add README guidance that complete bundles are high-review and domain bundles are preferred.

## What Not To Do

- Do not vendor either repository into `skills/`.
- Do not bulk install either repository.
- Do not run third-party scripts from either repository during source review.
- Do not treat privacy content as final regulatory authority.
- Do not treat cyber offensive workflows as safe defaults.
- Do not infer Codex/Cursor/Copilot support solely from a Claude marketplace listing.

## Evidence Map

- Repository scores: `repo-scorecards.tsv`.
- Domain inventory: `skill-taxonomy.tsv`.
- Runtime surface: `executable-surface.tsv`.
- Packaging observations: `marketplace-packaging-findings.tsv`.
- Reusable lessons: `reusable-patterns.tsv`.
- Risks and scanner candidates: `risk-register.tsv`.
- Candidate decisions: `import-candidates.tsv`.
- Conversion opportunities: `conversion-opportunities.tsv`.
- Policy upgrades: `source-policy-upgrades.md`.
