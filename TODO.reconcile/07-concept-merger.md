# 07 — ConceptMerger + ReconciledConcept

## Goal

Merge termbase and live concepts into a single `ManagedConcept` with
full lifecycle data, and package it with its `ChangeSet` in a
`ReconciledConcept` value object.

## ReconciledConcept

```ruby
ReconciledConcept = Struct.new(:managed_concept, :change_set, :source,
                               keyword_init: true)
# source: :both | :termbase_only | :live_only
```

## Merge rules

| Source | Behavior |
|--------|----------|
| both | live content + termbase dates; if changes detected, add ConceptDate(amended) + annotations |
| termbase only | mark retired, add ConceptDate(retired), preserve full content |
| live only | new concept, add ConceptDate(accepted) from publication date |

## Checklist

- [x] Implement ReconciledConcept (Struct)
- [x] Implement ConceptMerger
- [x] Spec: merge-both produces live content + termbase dates
- [x] Spec: termbase-only produces retired status
- [x] Spec: live-only produces accepted date
- [x] Spec: changes produce annotation entries
