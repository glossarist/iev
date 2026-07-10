# 04 — Concept merger

## Goal

For each code in the union of termbase + live sources, merge the two
into a single V3 `ManagedConcept` with full lifecycle data.

## Three populations

1. **In both** (~16,643 codes): termbase provides dates/status,
   live provides current content. If content differs, record an
   amendment.
2. **Termbase only** (~5,585 codes): not on live Electropedia → mark
   `status: retired`, add `ConceptDate(type: retired)`.
3. **Live only** (~830 codes): not in 2020 termbase → new concept,
   `ConceptDate(type: accepted)` from HTML publication date.

## Merge rules

| Field | Source |
|-------|--------|
| `identifier` | either (same code) |
| `status` | termbase `entry_status` → mapped to `ConceptStatus` enum |
| `dates` | termbase `date_accepted`/`date_amended`/`review_date`/`review_decision_date` → `ConceptDate` array |
| `localized_concepts.designations` | **live** if available, else termbase |
| `localized_concepts.definition` | **live** if available, else termbase |
| `localized_concepts.notes/examples` | **live** if available, else termbase |
| `sources` | live parsed sources (richer) |
| `related` | termbase supersession data + any extracted from live |

## Status mapping

| Termbase `entry_status` | V3 `ConceptStatus` |
|--------------------------|---------------------|
| `Standard` / `Published` | `valid` |
| `Draft` | `draft` |
| `Not Valid` | `notValid` |
| `Superseded` | `superseded` |
| `Retired` / absent from live | `retired` |

## Checklist

- [x] Define merge rules
- [x] Implement ConceptMerger
- [x] Test: in-both, termbase-only, live-only cases
