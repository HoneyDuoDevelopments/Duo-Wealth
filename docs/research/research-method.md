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
- **Confirmed** — multiple credible sources agree, or we validated directly
- **Strong support** — credible sources agree, not yet validated ourselves
- **Mixed** — sources disagree or evidence is incomplete
- **Open question** — not enough information to conclude
- **Needs live validation** — can only be resolved by running it

### Implications
What does this mean for the architecture? For implementation?

### Recommended Decision
What should we do based on this? Links to ADR if decision was made.

### Unresolved Questions
Anything still open. Gets added to open-questions.md.

## Research-to-Decision Rule

Research findings do not directly change architecture. Every research topic
must result in one of:

- An ADR (decision made based on evidence)
- A blueprint update (architecture change justified by research)
- A contract update (interface change based on new understanding)
- A roadmap task (something to build or investigate further)
- "No action" (research confirmed current approach is correct)

This prevents research from becoming a pile of smart notes with no downstream effect.