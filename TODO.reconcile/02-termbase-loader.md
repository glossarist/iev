# 02 — Termbase loader

## Goal

Load `iev-data/termbase.yaml` into a uniform per-code hash keyed by IEV
code. The termbase is the authoritative source for lifecycle dates and
historical content.

## What termbase.yaml contains

22,228 concepts in the old ISO/IEV termbase format:

```yaml
102-01-01:
  termid: 102-01-01
  term: equality
  eng:
    id: 102-01-01
    terms: [...]
    definition: "..."
    language_code: eng
    notes: [...]
    examples: [...]
    entry_status: Standard
    date_accepted: '2008-08-01T00:00:00+00:00'
    date_amended: '2008-08-01T00:00:00+00:00'
    review_date: '2008-08-01T00:00:00+00:00'
    review_decision_date: '2008-08-01T00:00:00+00:00'
    review_decision_event: published
  fra:
    ...
```

## Deliverable

Class: `Iev::Reconciler::TermbaseLoader`

- Loads termbase.yaml (22,228 concepts).
- Returns a Hash keyed by IEV code string → concept hash.
- Each concept hash normalizes per-language data into a consistent
  structure so downstream stages don't need to handle the old format
  ad-hoc.

## Checklist

- [x] Define TermbaseLoader interface
- [x] Implement
- [x] Test: loads all 22,228 codes; sample code has expected fields
