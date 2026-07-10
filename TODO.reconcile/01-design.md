# 01 — Reconciler design

## Goal

Design the reconciliation pipeline that merges `iev-data/termbase.yaml`
(historical, ~2020, 22,228 concepts) with the live HTML mirror
(`iev-data-latest/pages/`, 17,473 concepts) and outputs a single
Glossarist V3 dataset with full lifecycle history.

## Architecture

```
termbase.yaml ─┐
               ├─→ Reconciler ─→ ManagedConceptCollection ─→ concepts/*.yaml
live HTML ─────┘    (per code)      (V3 schema)
```

One orchestrator class: `Iev::Reconciler`. It loads both sources, walks
the union of all codes, and for each code produces a
`ManagedConcept` (V3) with:

- **Status + dates** from termbase (date_accepted, date_amended, review
  dates, entry_status).
- **Current content** (designations, definitions, notes, examples,
  sources) from live HTML when available; otherwise from termbase.
- **Diff detection**: if live content differs from termbase content,
  append a `ConceptDate(type: amended, date: <mirror date>)` to record
  that a change occurred between the last termbase snapshot and the
  mirror date.
- **Retirement**: codes in termbase but absent from the live mirror are
  marked `status: retired` with `ConceptDate(type: retired)`.
- **New concepts**: codes in the live mirror but absent from termbase
  get `ConceptDate(type: accepted)` from the HTML publication date.

## Output schema (Glossarist V3)

Each concept becomes a `ManagedConcept` file:

```yaml
---
schema_version: "3"
identifier: "102-01-01"
status: valid          # draft | notValid | valid | superseded | retired
dates:
  - type: accepted
    date: "2008-08-01"
  - type: amended
    date: "2008-08-01"
localized_concepts:
  eng:
    language: eng
    designations:
      - type: expression
        normative_status: preferred
        designation: equality
    definition: "..."
    sources:
      - type: authoritative
        status: identical
        origin: { ... }
data:
  domain: "Mathematics - General concepts and linear algebra"
  ...
related:
  - type: supersedes
    ref: IEV:102-01-00
```

## Checklist

- [x] Design the Reconciler architecture
- [x] Define the output schema mapping
- [x] Implement the pipeline (tasks 02–07)
