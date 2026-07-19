# AzerothCore Portable Realm — Canonical Stack Plan

Last updated: 2026-07-18

This file is the source of truth for the portable private AzerothCore realm used on the Steam Deck and maintained from the G14 laptop. Update this file whenever a component is accepted, rejected, replaced, tested, or pinned.

## Goal

Build a private, portable 3.3.5a-based Classic+ realm for personal and friends-only use with:

- Individual Vanilla → TBC → WotLK progression
- PlayerBots populating the world, dungeons, raids, battlegrounds, arenas, and faction-city assaults
- Steam Deck as a self-contained travelling server + client
- G14 as the main development, backup, AI, and heavy-build machine
- Good controller-friendly QoL without deleting the progression journey
- Selected level-scaled/replayable content
- Carefully tested class fixes and later-expansion mechanic backports
- Reproducible Git-pinned builds, database backups, and a merged client patch

## Synchronization Model

- This Git repository tracks plans, scripts, manifests, patches, module pins, and documentation.
- Steam Deck and G14 each clone this repository.
- Game databases and large client/server assets are not committed to Git.
- Database backups are synchronized separately as encrypted/compressed archives.
- Never edit the same plan file independently on both devices without pulling first.

Suggested local path on both devices:

```text
~/Projects/Stack-Setup-Curated
```

Basic sync:

```bash
git pull --ff-only
# edit files
git add projects/azerothcore-portable-realm
git commit -m "Update portable realm plan"
git push
```

## Status Legend

- ACCEPTED — intended for the stable stack
- EVALUATE — promising, compatibility/testing required
- LATER — intentionally deferred
- REJECTED — do not include
- REFERENCE — mine ideas/code patterns; not installed wholesale

## Foundation

| Component | Status | Decision |
|---|---|---|
| Dad's MMO Lab WotLK PlayerBots installer | ACCEPTED | Bootstrap the Steam Deck installation, then freeze exact commits after validation. |
| mod-playerbots/azerothcore-wotlk Playerbot branch | ACCEPTED | Required PlayerBots core fork. Pin commit after clean validation. |
| mod-playerbots | ACCEPTED | Primary bot system for world population, PvE, PvP, and controlled characters. Pin commit. |
| Docker-based deployment | ACCEPTED | Current DML path; verify persistence across SteamOS updates and maintain backups. |
| Crusaders Module Manager | EVALUATE | Useful folder-level module discovery/clone/backup/update utility. It does not build, apply SQL, prove compatibility, or replace our manifest. Linux packaging and DML/Docker path handling must be tested. |
| Tartampluch azerothcore-repack | REFERENCE | Integrated alternative orchestrator/repack, not a drop-in DML module. Mine build scripts, manifests, Eluna integration, web bridge, and UI patterns. Do not replace DML until a controlled comparative test exists. |

## Core Gameplay Stack

| Component | Status | Notes |
|---|---|---|
| Individual Progression | ACCEPTED | Backbone for per-character Vanilla → TBC → WotLK tiers. Requires compatibility patching/testing against current PlayerBots fork. |
| PlayerBot Level Brackets | ACCEPTED | Keeps bots distributed across active level ranges and progression caps. |
| AHBot | ACCEPTED | Needed for a functional solo/friends economy. |
| AutoBalance stable release | ACCEPTED, CAREFUL | Use party-size scaling. Level scaling should be a separate toggle/profile. Avoid double-scaling. |
| Quest Loot Party | ACCEPTED | Controller/friends QoL. |
| AoE Loot | ACCEPTED | Controller-friendly QoL. |
| Transmog | LATER | Low priority; add after DB/client stack stabilizes. |
| Dungeon Master procedural/roguelike module | EVALUATE | Strong level-scaled replay concept, but early-development and current schema compatibility issues exist. Add only after base stability. |
| Araxia Delves/custom content | LATER | Add selected content one component at a time after progression stack is stable. |
| Araxia Mythic-style content | LATER | More bot-mechanic risk than Delves. |
| Wrath Unbound/classless | REJECTED | Conflicts with desired class identity and progression design. |
| SoloCraft | REJECTED FOR BASE | Overlaps AutoBalance and risks trivializing content. |
| ARAC | REJECTED | Use UAC path instead; never combine overlapping race/class DBC systems. |
| UAC / all race-class combinations | LATER | Install only after client patch architecture is fixed. |

## Progression Policy

### Vanilla

- Level cap 60
- Vanilla raid/tier gating through Individual Progression
- WSG, AB, AV and honor progression
- Keep RDF and quest markers as optional QoL rather than automatically disabling them
- Do not immediately apply severe global damage/healing reductions; benchmark first

### TBC

- Level cap 70
- T4 → T5 → T6 progression
- Arena seasons 1–4
- Rebalance bot level brackets around 60–70

### WotLK

- Level cap 80
- Stock WotLK progression where possible
- Rebalance bot brackets around 70–80

## Death Knight Plan

Status: ACCEPTED DESIGN, CUSTOM IMPLEMENTATION REQUIRED

- Stock level-55 Acherus start
- Allow DK during Vanilla only after custom progression gear exists
- Vanilla DK gear: pre-raid, T0/T0.5/T1/T2/T2.5/T3 equivalents, honor sets
- TBC DK gear: dungeon/heroic pre-raid, T4/T5/T6, arena S1–S4, badge/reputation gear
- Prefer token exchange over adding DK items directly to every boss loot table
- Tank/DPS variants
- Reuse existing visual display IDs initially
- Keep bonuses based on existing DK spell IDs so PlayerBots understand them
- Curated bot gear templates may be needed because automated gear scoring may ignore set completion

## Class Balance and Fix Policy

- Prefer upstream AzerothCore/PlayerBots bug fixes.
- Do not install a broad unknown rebalance pack.
- Reproduce and document a bug before patching it.
- Separate actual bugs from WotLK-at-level-60/70 balance differences.
- Backport isolated later mechanics using existing spell IDs where possible.
- Add one class/mechanic change at a time with bot and player tests.
- Maintain phase-specific tuning rather than one global multiplier.

## PlayerBots and PvP

- Start with DML's tested bot settings, then profile rather than guessing.
- Track total bots separately from simultaneously active bots.
- Use Altbots for persistent long-term companions.
- Use AddClass bots for fast test compositions.
- Add a controller-friendly PlayerBot addon only after confirming command compatibility.
- Test WSG, AB, AV, arenas, and each raid tier before calling a build stable.

## Opposite-Faction City Raid System

Status: ACCEPTED LONG-TERM FEATURE

Goal: support multi-raid attacks on enemy capitals, not merely one 40-player raid.

Architecture:

```text
Human/AI strategic planner
        ↓
Validated City War Director (C++ or Eluna prototype)
        ↓
Multiple PlayerBot raid groups / squads
        ↓
Deterministic PlayerBot combat AI
        ↓
Addon or web dashboard for status and override
```

Desired features:

- Multiple 40-player raids or independent squads
- Staging areas and rally points
- Gate assault, flanking, reinforcement suppression, leader strike team
- Objective phases and reinforcement waves
- Army-level commands separate from individual combat logic
- Human override at all times
- Progressive load tests: 40 → 80 → 120 → 160+ simultaneous attackers

Do not use a giant slow LLM for real-time combat. AI may devise strategy; deterministic server code executes it.

## Addon and Client Compatibility

Expected to work normally:

- Action bars, unit/raid frames, meters, threat, bags, controller addons
- Existing-spell WeakAuras
- PlayerBot control addons after command/protocol verification

Potentially inaccurate without custom data:

- Questie
- AtlasLoot/AtlasQuest
- DBM for restored/custom encounters
- GearScore before WotLK

Client patch policy:

- Merge Individual Progression, UAC, custom DK sets, Araxia, and later-mechanic DBC/MPQ changes into one controlled patch set.
- Do not stack conflicting MPQs blindly.
- Record patch load order and checksums.

## Tartampluch Components

### azerothcore-repack

Status: REFERENCE / POSSIBLE ALTERNATIVE BASE TEST

It is a self-contained realm orchestrator, similar in category to DML but broader: AzerothCore + PlayerBots + many modules + web/AoWoW/frontend/client-patch orchestration. It is not one module and is not plug-and-play inside DML.

### Eluna scripts

Status: EVALUATE INDIVIDUALLY

Promising pieces:

- Adventure Assistant NPC/menu architecture
- Per-character persistent settings
- Hot-reloadable Lua workflow
- Web-admin command queue/bridge
- Localization structure
- AI/server command-queue pattern

Not plug-and-play because they assume:

- mod-ALE/Eluna installed and configured
- exact Lua paths/bind mounts
- custom database tables
- specific NPC entries and third-party module commands
- companion C++ modules and web components

Progression-breaking features must be disabled or permission-gated: quest auto-complete, unrestricted spell learning, world flying, cheats, and free recovery tools.

### Repository audit status

- Verified directly: `azerothcore-repack` and `azerothcore-repack-eluna-scripts`
- Referenced but not yet fully audited: `azerothcore-repack-rag`, `lua-learnspells`, and any other projects not exposed by the public profile/index
- Previous claim of checking every project was incorrect; a literal complete crawl remains open

## AI and Development Tools

| Component | Status | Role |
|---|---|---|
| Codex CLI on Steam Deck | ACCEPTED | Local repository agent while online. |
| Codex/Claude Code on G14 | ACCEPTED | Main development agents. |
| Colibrì + giant GLM model on G14 | EVALUATE/EXPERIMENT | Offline slow text reasoning; not real-time control and not image generation. Requires large fast NVMe allocation. |
| ComfyUI/image models on G14 | ACCEPTED SEPARATELY | Product/art/image generation; separate from Colibrì. |
| Small local LLM for live decisions | LATER | Only for infrequent structured strategic commands; deterministic execution required. |
| Realm RAG/knowledge base | EVALUATE | Index configs, module docs, commands, schema, known bugs, and progression rules. |

## DML Base Audit — Current Findings

- Active maintenance and very recent installer fixes
- Clean installer currently clones moving Playerbot/master branches rather than pinned commits
- No evidence of a comprehensive automated integration/regression suite
- Historical issues include Docker/SteamOS installation persistence, dependency/keyring handling, first-boot/database failures, long boot times, and module-manager SQL import conflicts
- Current open concerns include Death Knight creation and a PlayerBot addon/command report
- Reports also exist of successful fresh WotLK PlayerBot operation on Steam Deck

Conclusion: viable bootstrap, not proven bug-free. Validate the exact clean build before adding extras, then freeze commits and database snapshots.

## Clean-Build Acceptance Test

Before adding any optional module:

1. Record exact DML, core, and PlayerBots commits.
2. Confirm server survives reboot and SteamOS update workflow.
3. Create normal characters and a Death Knight.
4. Confirm PlayerBot chat commands and chosen control addon.
5. Run 5-player dungeon with bots.
6. Run WSG and AB.
7. Run one supported raid encounter.
8. Measure world update time, RAM, swap, CPU, thermals, and client frame pacing at DML bot defaults.
9. Back up auth, characters, world DBs, configs, compose files, and client patch checksum.
10. Tag the validated state as `clean-playerbots-baseline`.

## Installation Order

1. DML clean PlayerBots base
2. Validate and pin commits
3. Baseline backup/tag
4. Individual Progression
5. Bot Level Brackets
6. AHBot
7. AutoBalance stable
8. Quest Loot Party
9. AoE Loot
10. Second backup/tag
11. DK progression gear
12. UAC and merged client patch
13. Selected class fixes/backports
14. Dungeon Master after compatibility repair
15. Adventure Assistant/Eluna control layer
16. City War Director prototype
17. Selected Araxia content
18. RAG/operator documentation

## Rejected Practices

- Install every available module
- Trust a module manager as compatibility proof
- Auto-run unknown SQL against the only database
- Update moving branches without a snapshot
- Mix ARAC and UAC
- Stack multiple overlapping scaling systems
- Let an LLM directly issue unrestricted server/database commands
- Store the only database copy on one device

## Immediate Next Actions

- [ ] Clone this plan repo on Steam Deck and G14
- [ ] Complete literal inventory of all Tartampluch public projects before deletion
- [ ] Archive useful Tartampluch repositories
- [ ] Install and validate current DML clean base on Steam Deck
- [ ] Record exact commit SHAs
- [ ] Decide DB backup/sync location and encryption method
- [ ] Test Crusaders Module Manager against a disposable clone, not the live server
- [ ] Select one maintained PlayerBot control addon/protocol
- [ ] Create module lock manifest and compatibility test log
