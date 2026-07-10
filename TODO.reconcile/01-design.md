# 01 — Architecture & autoloads

## Audit of current approach (scripts/reconcile.rb)

Problems:
1. **Monolithic** — 400-line script, module of static methods, no classes
2. **Not model-driven** — builds raw Hashes instead of Glossarist model objects
3. **No field-level diff** — knows THAT content changed, not WHAT changed
4. **No before/after values** — loses the historical content
5. **No machine-readable change log** — no way to audit changes
6. **No specs**
7. **Not MECE** — merge, diff, serialize all mixed together
8. **Not autoloaded** — everything in a script file

## New architecture

```
lib/iev/reconciler.rb                      module + autoloads
lib/iev/reconciler/change.rb               field-level change (field, lang, old, new)
lib/iev/reconciler/change_set.rb           collection of Change per concept
lib/iev/reconciler/status_mapper.rb        termbase status -> V3 ConceptStatus
lib/iev/reconciler/termbase_loader.rb      termbase.yaml -> {code => ManagedConcept}
lib/iev/reconciler/live_loader.rb          HTML pages -> {code => ManagedConcept}
lib/iev/reconciler/content_differ.rb       diff two ManagedConcepts -> ChangeSet
lib/iev/reconciler/concept_merger.rb       merge termbase + live -> ReconciledConcept
lib/iev/reconciler/reconciled_concept.rb   ManagedConcept + ChangeSet + source
lib/iev/reconciler/report.rb               dataset-level change reporting
lib/iev/reconciler/pipeline.rb             orchestration
```

Each class has ONE responsibility (MECE). The Pipeline composes them.

## History reporting

Three layers:

1. **Model-level** — `ManagedConcept#dates` (accepted/amended/retired),
   `ManagedConcept#status` (valid/draft/superseded/retired),
   `ManagedConcept#related` (supersedes/superseded_by).

2. **Concept-level annotations** — Each amended concept gets a
   `ConceptData#annotations` entry describing what field changed, with
   before/after text.

3. **Dataset-level report** — Summary statistics + machine-readable
   change log written to `report/`:
   - `summary.yaml` — aggregate counts by change type, section, language
   - `changes.csv` — one row per field-level change
   - `retired.yaml` — concepts retired since termbase snapshot
   - `new_concepts.yaml` — concepts added since termbase snapshot

## Checklist

- [x] Audit current approach
- [x] Design new architecture
- [x] Create lib/iev/reconciler.rb with autoloads
- [x] Register in lib/iev.rb
