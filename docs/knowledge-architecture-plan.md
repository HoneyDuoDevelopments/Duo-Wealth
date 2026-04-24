# HoneyDuo Wealth — Documentation & Knowledge Architecture Plan

## Purpose

This document defines the documentation structure for the Strategy Incubator project. The goal is to organize knowledge so that any future development session can start productive within minutes by uploading the relevant document(s) — no re-explaining the system, no context archaeology.

Every document has a defined scope, a size target, and clear rules about what belongs in it vs. what belongs somewhere else. This prevents doc sprawl, keeps individual files small enough to fit in a chat context window, and ensures nothing important is orphaned.

-----

## Core Principles

1. **Docs live with the code.** Everything is in the GitHub repo under `/docs`. If it’s not in the repo, it doesn’t exist.
1. **Each doc should be uploadable on its own.** A future session should need at most 2-3 docs to have full context for a task. If you need to upload 5+ docs to explain what you’re doing, the structure is wrong.
1. **One doc, one concern.** The blueprint doesn’t contain module specs. Module specs don’t contain ADRs. ADRs don’t contain implementation notes. Clean separation.
1. **Write docs when you build, not before.** The structure is defined now. The content gets written when the module is being designed or built. Empty placeholder files are fine — they mark what will exist.
1. **Size discipline.** No single doc should exceed ~3,000 words / ~4,000 tokens. If it does, it needs to be split. This keeps every doc uploadable without consuming excessive context window.

-----

## Canonical Sources

When information conflicts between documents, these are the sources of truth:

- `blueprint.md` — canonical for system architecture, module boundaries, and dependencies
- `contracts/*.md` — canonical for shared interface definitions
- `modules/*.md` — canonical for module-specific behavior and internal design
- `adrs/*.md` — canonical for decision rationale (why something was chosen)
- `roadmap.md` — canonical for current priorities and build sequence
- `docs/research/*.md` — canonical for research findings and evidence
- `session-guides/*.md` — canonical for AI session workflow (committed project assets, not throwaway notes)

If a module spec contradicts the blueprint, the blueprint wins and the spec must be updated. If code contradicts a contract, the contract wins and the code has a bug. If an ADR is superseded, it gets a status update pointing to the new ADR — it is never deleted.

-----

## Doc Update Triggers

- **Code changes a contract** → update the contract doc immediately. Code and contract ship together.
- **Architecture changes** → update `blueprint.md` + write an ADR explaining the change.
- **Implementation deviates from plan** → update the module spec. Specs reflect reality, not wishes.
- **Priorities shift** → update `roadmap.md`.
- **Major decision made** → write an ADR before the session ends.
- **Research changes a conclusion** → update the research doc, then decide: ADR, blueprint update, contract change, roadmap task, or “no action.”

-----

## Naming & Versioning Conventions

- **Docs use stable filenames.** `m01-data-layer.md` doesn’t become `m01-data-layer-v2.md`. The file persists, the content evolves.
- **`blueprint.md` version increments only on architecture changes.** Adding implementation detail doesn’t bump the version. Adding a module does.
- **ADRs are immutable except status field.** Once accepted, the body doesn’t change. If the decision is reversed, write a new ADR that supersedes it and update the old ADR’s status to “Superseded by ADR-XXX.”
- **Module specs get changelog entries, not silent rewrites.** Every meaningful change to a spec gets a dated entry at the bottom so you can see how the design evolved.

-----

## Repo Structure

```
honeyduo-wealth/
│
├── README.md                          # Project overview, quick-start, links to docs
│
├── docs/
│   ├── blueprint.md                   # System blueprint (v0.2.1 — the end-state definition)
│   │
│   ├── contracts/                     # Shared interface specifications
│   │   ├── strategy-contract.md       # Interface every strategy implements
│   │   ├── scorecard-format.md        # Standardized evaluation output
│   │   ├── run-manifest-format.md     # What every run records
│   │   ├── kill-record-format.md      # What gets logged when a strategy dies
│   │   ├── promotion-demotion-rules.md # Canonical gate criteria at each transition
│   │   ├── alert-event-schema.md      # Standardized event format for notifications
│   │   └── broker-abstraction.md      # Internal interface for broker interaction
│   │
│   ├── modules/                       # One spec per module (written when module is being built)
│   │   ├── m01-data-layer.md
│   │   ├── m02-strategy-factory.md
│   │   ├── m03-feature-registry.md
│   │   ├── m04-backtest-engine.md
│   │   ├── m05-metrics-grading.md
│   │   ├── m06-experiment-tracking.md
│   │   ├── m07-research-governance.md
│   │   ├── m08-tournament-arena.md
│   │   ├── m09-paper-trading.md
│   │   ├── m10-graveyard.md
│   │   ├── m11-portfolio-risk.md
│   │   ├── m12-live-deployment.md
│   │   ├── m13-alerts.md
│   │   ├── m14-regime-monitor.md
│   │   └── m15-adaptive-allocation.md
│   │
│   ├── adrs/                          # Architecture Decision Records
│   │   ├── ADR-000-template.md        # Template for new ADRs
│   │   ├── ADR-001-vectorbt-as-backtest-core.md
│   │   ├── ADR-002-ib-insync-provisional.md
│   │   └── ADR-003-mysql-data-storage.md
│   │
│   ├── research/                      # Research findings, evidence, open questions
│   │   ├── research-method.md         # How we do research (template, evidence labels, rules)
│   │   ├── open-questions.md          # Unresolved questions register
│   │   └── topics/                    # One file per research topic
│   │       ├── data-providers.md      # Data provider comparison and selection
│   │       ├── backtesting-landscape.md # Framework comparison (VectorBT, Backtrader, etc.)
│   │       ├── broker-api-options.md  # ib_insync alternatives, IBKR integration paths
│   │       ├── cost-modeling.md       # Slippage, commission, market impact research
│   │       └── regime-detection.md    # Approaches to market regime classification
│   │
│   ├── roadmap.md                     # Build sequence, phase plan, current priorities
│   │
│   └── session-guides/               # Pre-packaged context bundles for common work sessions
│       │                              # (committed project assets — maintained, not throwaway)
│       ├── guide-data-layer.md        # "Upload this + blueprint when working on data layer"
│       └── guide-backtest-engine.md   # "Upload this + blueprint when working on backtester"
│
├── src/                               # Source code (organized by module)
│   ├── data/
│   ├── strategy/
│   ├── features/
│   ├── backtest/
│   ├── metrics/
│   ├── tracking/
│   ├── tournament/
│   ├── paper/
│   ├── portfolio/
│   ├── live/
│   ├── alerts/
│   ├── regime/
│   └── shared/                        # Utilities, config, shared types
│
├── tests/                             # Test suite mirroring src/ structure
│
├── strategies/                        # Strategy definitions (YAML/JSON + Python)
│   ├── active/
│   ├── tournament/
│   ├── development/
│   └── graveyard/
│
├── templates/                         # Reusable templates
│   ├── idea-intake.md                 # Research governance intake form
│   ├── strategy-metadata.yaml        # Metadata schema template
│   └── kill-record.md                 # Post-mortem template
│
└── data/                              # Local data (gitignored except schemas)
    ├── .gitkeep
    └── schemas/                       # Data schemas (tracked)
```

-----

## Document Definitions

### blueprint.md

**Scope:** The complete end-state system definition. What the incubator will be when fully realized. All 15 modules, all cross-cutting contracts, system tree, strategy lifecycle, technology stack, dependency map.
**Does NOT contain:** Implementation details, code, module-level specs, build timeline.
**When to update:** When a module is added/removed, a dependency changes, or a major architectural boundary shifts.
**When to upload:** Almost every session. This is the north star. Keep it lean enough to always fit.
**Target size:** ~3,000 words (current v0.2.1 is at the upper bound — may need trimming as modules get their own specs and detail migrates out).

-----

### contracts/*.md

**Scope:** Each file defines one shared interface specification. The exact schema, fields, types, rules, and constraints that multiple modules depend on. These are the integration points.
**Does NOT contain:** Implementation code, module-specific logic, rationale for why the contract exists (that goes in an ADR if needed).
**When to write:** When the first module that depends on this contract is being built. The contract must exist before the module is implemented.
**When to upload:** When working on any module that uses this contract.
**Target size:** 500-1,500 words each. These should be tight and precise.

**Contract inventory:**

|Contract                   |Write when building   |Used by modules             |
|---------------------------|----------------------|----------------------------|
|strategy-contract.md       |M2 Strategy Factory   |M2, M4, M5, M8, M9, M11, M12|
|scorecard-format.md        |M5 Metrics & Grading  |M5, M8, M9, M10, M11, M12   |
|run-manifest-format.md     |M6 Experiment Tracking|M6, M4, M8, M9, M12         |
|kill-record-format.md      |M10 Graveyard         |M10, M5, M6                 |
|promotion-demotion-rules.md|M8 Tournament Arena   |M8, M9, M11, M12            |
|alert-event-schema.md      |M13 Alerts            |M13, all event emitters     |
|broker-abstraction.md      |M9 Paper Trading      |M9, M12                     |

-----

### modules/*.md

**Scope:** Each file is the detailed specification for one module. Internal architecture, data flows, function signatures, configuration, error handling, edge cases, testing approach. This is what you upload when you’re building that module.
**Does NOT contain:** The why (that’s in the blueprint), shared interface definitions (those are in contracts), or decision rationale (that’s in ADRs).
**When to write:** When the module is being designed and built. Start with an outline, flesh out as implementation progresses. Capture decisions and learnings during development.
**When to upload:** When working on this specific module or a module that directly interfaces with it.
**Target size:** 1,000-2,500 words each. Enough to fully specify the module without bloat.

**Content template for module specs:**

```markdown
# M[N]: [Module Name] — Specification

## Overview
One paragraph — what this module does and why it exists.

## Interfaces
- Inputs: what data/events does this module consume, and from where?
- Outputs: what data/events does this module produce, and for whom?
- Contracts: which shared contracts does this module implement or depend on?

## Internal Architecture
How the module is structured internally. Key classes, data flows, state management.

## Configuration
What's configurable. Defaults. Environment-specific overrides.

## Error Handling
What can go wrong. How each failure mode is handled. What gets alerted.

## Testing Approach
How this module is tested. Unit tests, integration points, edge cases to cover.

## Dependencies
External libraries, internal modules, data requirements.

## Open Questions
Anything unresolved at time of writing.

## Changelog
Date-stamped changes to this spec.
```

-----

### adrs/*.md

**Scope:** Each file records one major design decision. What was decided, why, what alternatives were considered, and what would cause a revisit. These are the institutional memory of the project.
**Does NOT contain:** Implementation details, specs, or ongoing status tracking.
**When to write:** When a significant decision is made — technology choice, module boundary, contract design, build-vs-buy, major architectural change.
**When to upload:** When working on anything related to the decision, or when someone (you or AI) is questioning why something was done a certain way.
**Target size:** 300-800 words each. Brief and decisive.

**ADR template:**

```markdown
# ADR-[NNN]: [Decision Title]

## Status
[Accepted / Superseded by ADR-XXX / Deprecated]

## Date
[YYYY-MM-DD]

## Context
What situation or question prompted this decision?

## Decision
What did we decide?

## Alternatives Considered
What other options existed and why were they rejected?

## Consequences
What does this decision enable? What does it constrain?

## Revisit If
Under what conditions should we reconsider this decision?
```

**Initial ADRs to create:**

|ADR    |Decision                                             |Write when      |
|-------|-----------------------------------------------------|----------------|
|ADR-001|VectorBT (open source) as backtest core              |Phase 1 kickoff |
|ADR-002|ib_insync as provisional, broker abstraction required|Phase 1 kickoff |
|ADR-003|MySQL on Honey Duo as primary data storage           |When building M1|
|ADR-004|Python as sole language                              |Phase 1 kickoff |
|ADR-005|Alpaca for tournament paper trading                  |When building M8|

More will emerge during development. Any decision that a future session might question deserves an ADR.

-----

### roadmap.md

**Scope:** Current build sequence, phase definitions, what’s in progress, what’s next, what’s blocked. The living plan.
**Does NOT contain:** System architecture (that’s blueprint.md), module specs, or decision history.
**When to update:** At the start or end of each build phase, or when priorities shift.
**When to upload:** When planning work or starting a new phase.
**Target size:** 500-1,000 words. Keep it scannable.

**Content structure:**

```markdown
# Roadmap

## Current Phase
What phase we're in. What's actively being built.

## Recently Completed
What was finished and when.

## Next Up
What's queued after current phase.

## Blocked / Waiting
Anything that can't proceed and why.

## Phase Definitions
Brief description of each phase and its exit criteria.

## Backlog
Ideas and tasks that aren't prioritized yet.
```

-----

### session-guides/*.md

**Scope:** Pre-packaged context bundles. Each guide tells you exactly what to upload and what context to set when starting a specific type of work session.
**Does NOT contain:** The actual specs or architecture — it points to them.
**When to write:** When a module or work area is mature enough that you’ll have repeat sessions on it.
**When to upload:** You don’t upload these to me — these are for YOU to reference before starting a session. They tell you what TO upload.
**Target size:** 200-500 words each. Just a checklist and context summary.

**Session guide template:**

```markdown
# Session Guide: [Work Area]

## Upload These Files
- docs/blueprint.md (always)
- docs/modules/mXX-[module].md
- docs/contracts/[relevant-contract].md
- [any relevant source files]

## Context Summary
[2-3 sentences — what this module does, where it sits in the system,
what's already built, what's in progress]

## Current State
[What exists. What works. What's broken or incomplete.]

## Goals for This Session
[What we're trying to accomplish]

## Key Constraints
[Anything the AI needs to know — dependencies, tech decisions, gotchas]
```

-----

### research/research-method.md

**Scope:** Defines how research is conducted, documented, and converted into system decisions. The rules of the research process.
**Does NOT contain:** Actual research findings (those go in topic files).
**When to write:** Now — before any formal research begins.
**When to upload:** When starting a research session.
**Target size:** 500-800 words.

**Content:**

```markdown
# Research Method

## How Research Works in This Project

Research answers questions that affect architecture, implementation, or strategy.
Every research effort starts with a question, produces findings, and ends with
a decision or an explicit "open question" entry.

## Research Note Template

Every topic file in research/topics/ follows this structure:

### Question
What are we trying to answer?

### Why It Matters
What system decision depends on this?

### Sources Reviewed
What did we look at? (links, docs, tools tested, conversations)

### Key Findings
What did we learn? Each finding gets an evidence label:
- Confirmed — multiple credible sources agree, or we validated directly
- Strong support — credible sources agree, not yet validated ourselves
- Mixed — sources disagree or evidence is incomplete
- Open question — not enough information to conclude
- Needs live validation — can only be resolved by running it

### Implications
What does this mean for the architecture? For implementation?

### Recommended Decision
What should we do based on this? Links to ADR if decision was made.

### Unresolved Questions
Anything still open. Gets added to open-questions.md.
```

-----

### research/open-questions.md

**Scope:** Single register of all unresolved questions across the project. Prevents open items from disappearing into chat history.
**Does NOT contain:** Answers (those go in research topic files or ADRs).
**When to update:** When a new question surfaces during any session, or when a question gets resolved.
**When to upload:** When planning research or when starting a session and needing to check what’s unresolved.
**Target size:** Should stay under 1,000 words. If it grows too large, questions are not being resolved.

**Format:**

```markdown
# Open Questions

| # | Question | Raised | Matters for | What would resolve it | Status |
|---|----------|--------|-------------|----------------------|--------|
| 1 | Which data provider for minute bars? | 2026-04 | M1 Data Layer | Cost/coverage comparison | Open |
| 2 | ib_insync replacement candidate? | 2026-04 | M9, M12 | Test ib_async or direct TWS | Open |
| 3 | Tournament minimum duration? | 2026-04 | M8 | Need real tournament data | Open |
```

-----

### research/topics/*.md

**Scope:** One file per research topic. Contains the full research record following the template defined in research-method.md.
**Does NOT contain:** Decisions (those are ADRs). Architecture changes (those go in blueprint.md).
**When to write:** When a question needs real investigation — not a quick lookup, but comparing options, reviewing sources, testing tools.
**When to upload:** When continuing research on that topic, or when making a decision that depends on the research.
**Target size:** 800-2,000 words. Enough to capture findings without becoming a dissertation.

**Research-to-decision rule:** Research findings do not directly change architecture. They must result in one of:

- An ADR (decision made based on evidence)
- A blueprint update (architecture change justified by research)
- A contract update (interface change based on new understanding)
- A roadmap task (something to build or investigate further)
- “No action” (research confirmed current approach is correct)

This prevents research from becoming a pile of smart notes with no downstream effect.

-----

## How This Works in Practice

**Starting a new build session:**

1. Check `roadmap.md` — what are we working on?
1. Check the session guide for that area (if one exists)
1. Upload to Claude: `blueprint.md` + the relevant module spec + any relevant contracts
1. State what you’re trying to accomplish
1. Build

**Making a decision:**

1. Discuss in session
1. Write an ADR
1. Commit to `/docs/adrs/`

**Doing research:**

1. Check `open-questions.md` — is this question already tracked?
1. Check `research/topics/` — has this been researched before?
1. If new: create a topic file, follow the template in `research-method.md`
1. When findings are solid: decide on downstream action (ADR, blueprint update, contract change, roadmap task, or no action)
1. Update `open-questions.md` — resolve answered questions, add new ones

**Finishing a module or phase:**

1. Update the module spec with what was actually built (vs. what was planned)
1. Update `roadmap.md`
1. Write any ADRs for decisions made during the phase
1. Update `blueprint.md` if any architectural boundaries shifted

**Onboarding a new AI session after a long break:**

1. Upload `blueprint.md` + `roadmap.md`
1. That gives full system context + current state
1. Then upload the specific module spec for whatever you’re working on

-----

## What Gets Written Now vs. Later

### Write now (before any code):

- This document (done)
- `blueprint.md` (done — v0.2.1)
- `roadmap.md` (next — once we define the game plan)
- `ADR-000-template.md` (the template itself)
- `research/research-method.md` (research rules and template)
- `research/open-questions.md` (seed with questions from blueprint)
- `research/topics/backtesting-landscape.md` (capture findings from this session)
- Repo structure (create the folder skeleton)

### Write when building Phase 1:

- `modules/m01-data-layer.md`
- `modules/m02-strategy-factory.md`
- `modules/m03-feature-registry.md`
- `modules/m04-backtest-engine.md`
- `modules/m05-metrics-grading.md`
- `modules/m06-experiment-tracking.md`
- `contracts/strategy-contract.md`
- `contracts/scorecard-format.md`
- `contracts/run-manifest-format.md`
- ADRs 001-004

### Write when building Phase 2:

- `modules/m07-research-governance.md`
- `modules/m08-tournament-arena.md`
- `modules/m09-paper-trading.md`
- `modules/m10-graveyard.md`
- `contracts/promotion-demotion-rules.md`
- `contracts/kill-record-format.md`
- `contracts/broker-abstraction.md`

### Write when building Phase 3+:

- Everything else, as needed

-----

## Anti-Patterns to Avoid

1. **The mega-doc.** If any file exceeds ~3,000 words, split it. Giant docs defeat the purpose of targeted context loading.
1. **Spec drift.** If the code diverges from the spec, update the spec. A stale spec is worse than no spec because it actively misleads.
1. **ADR avoidance.** If you made a decision and didn’t write it down, you WILL re-litigate it in 3 months. Take 5 minutes, write the ADR.
1. **Session guide neglect.** These are low effort, high payoff. After your third session on the same module, write the guide. Future you will thank past you.
1. **Docs without code, code without docs.** They ship together. A PR that adds a module without updating its spec is incomplete.
1. **Research without resolution.** Every research topic must end with a downstream action: ADR, blueprint update, contract change, roadmap task, or explicit “no action.” Research that just sits there unresolved is a waste of the effort that produced it.
1. **Chat-only knowledge.** If something important was discussed in a Claude/GPT session but never made it into a doc, it doesn’t exist. End-of-session habit: ask “did we learn or decide anything that needs to be captured?”

-----

*Document version: 1.1*
*Created: April 2026*
*Status: Active — defines documentation and research structure for the project*
*Changelog v1.1: Added canonical source rules, doc update triggers, naming/versioning conventions, session guides as committed assets. Added research layer: research-method.md, open-questions.md, topic files, evidence labels, research-to-decision rule. Added research workflow to How This Works in Practice. Added research anti-patterns.*