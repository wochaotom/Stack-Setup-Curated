# Source Policy Upgrades

Evidence base:

- `mukul975/Anthropic-Cybersecurity-Skills` pinned at `0f429d0f96ee70d2a6c259c4ecc6c6e18e0d23ff`.
- `mukul975/Privacy-Data-Protection-Skills` pinned at `9b2ef9eae161c00a17241d42a388571321b33e9f`.
- Both were inspected as untrusted community sources. No third-party scripts were executed.

## Policy Changes To Carry Forward

1. Split source review into two scores: `source_trust` and `install_safety`.
   Evidence: cyber has high public signal but 1,032 scripts; privacy has lower public signal but cleaner quick-scan results.

2. Treat marketplace listings as acquisition surfaces, not adapter authority.
   Evidence: both repos provide `.claude-plugin/marketplace.json`, but target behavior for Codex, Cursor, Copilot, or Windsurf still needs official target docs.

3. Accept marketplace-only sources when they are sole-source candidates, but require provenance review.
   Evidence: both repos expose useful domain-specific skills that may not exist natively on other platforms.

4. Require pinned refs for all community skill/plugin recommendations.
   Evidence: both repos have active branches and large content surfaces, so branch drift matters.

5. Add an executable-surface gate before install recommendations.
   Evidence: cyber has 1,032 scripts and privacy has 824 scripts in the pinned snapshots.

6. Add a high-risk-domain gate.
   Evidence: cyber includes offensive and malware-related workflows; privacy includes high-stakes regulatory workflows.

7. Add fixture-aware scanner treatment.
   Evidence: both repos contain prompt-injection strings in defensive/test contexts. These should be flagged for review but not automatically treated as malicious directives.

8. Add manifest/count consistency checks.
   Evidence: large marketplace repos can drift between README, plugin metadata, indexes, and filesystem counts.

9. Add duplicate-derived-artifact drift checks.
   Evidence: privacy stores root skills and plugin-packaged copies, which can diverge without a generator or hash check.

10. Add a primary-source freshness rule for compliance claims.
    Evidence: privacy `SECURITY.md` explicitly treats inaccurate regulatory citations as a reportable issue.

## Scanner Rule Candidates

- Prompt-injection directive: direct phrases such as "ignore previous instructions"; downgrade only when quoted as fixture data.
- Fetch-and-execute: `curl`, `wget`, `iwr`, or `Invoke-WebRequest` piped to shell/interpreter.
- Dynamic PowerShell execution: `Invoke-Expression` and `iex`, with context-aware allowance for detection examples.
- Secret-shaped strings: OpenAI keys, GitHub tokens, cloud keys; allow fake examples only after fixture classification.
- Offensive cyber verbs: exploit, payload, C2, beacon, crack, persistence, privilege escalation, ransomware.
- Network/scan tools: nmap, masscan, burp, sqlmap, hydra, aircrack; require target authorization.
- Tool install/mutation: apt, brew, pip install, docker run, chmod, service/systemctl.
- Script capability extraction: subprocess, requests, sockets, cloud SDKs, filesystem deletion, environment variables.
- Regulatory staleness: GDPR, HIPAA, CCPA, CPRA, PIPL, DPDP, EU AI Act, SCC, BCR claims require date/source fields.
- Template PII: sample names, emails, patient/employee/customer data in assets or generated docs.

## Prioritized Implementation Backlog

1. P0: Add source scorecard output to `stack-setup-audit` JSON for community marketplace candidates.
   Evidence: `repo-scorecards.tsv` shows trust and install safety diverge.

2. P0: Extend `scan_skills.ps1` with review-level findings for fetch-execute, secret fixtures, and offensive cyber terms.
   Evidence: `risk-register.tsv` R002, R006, R007.

3. P0: Add source-review invariant: never run third-party scripts during source review.
   Evidence: both repos have hundreds of scripts.

4. P1: Add marketplace manifest count and source-path sanity checks.
   Evidence: `marketplace-packaging-findings.tsv` MP08, MP10, MP19.

5. P1: Add duplicate packaged-skill drift check for repos with root and plugin copies.
   Evidence: `risk-register.tsv` R008.

6. P1: Add legal/regulatory staleness field for privacy/compliance candidates.
   Evidence: privacy `SECURITY.md` and `CHANGELOG.md`.

7. P1: Add candidate classification vocabulary: keep, convert, link, reject.
   Evidence: `import-candidates.tsv`.

8. P2: Add optional machine-readable source index ingestion for repos with `index.json`.
   Evidence: cyber `index.json`.

9. P2: Add coverage-matrix output for framework-mapped source repos.
   Evidence: cyber `ATTACK_COVERAGE.md`.

10. P2: Add README guidance for complete bundle versus domain plugin install strategy.
    Evidence: privacy marketplace segmentation.
