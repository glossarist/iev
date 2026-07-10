# 04 — TermbaseLoader

## Goal

Load `termbase.yaml` and build `Glossarist::ManagedConcept` objects
with full lifecycle dates from the old termbase format.

## Input

`iev-data/termbase.yaml` — 22,228 concepts in old ISO/IEV format.

## Output

`Hash<String, Glossarist::ManagedConcept>` keyed by IEV code.

Each ManagedConcept has:
- `id` = code
- `status` from StatusMapper
- `dates` from `date_accepted` + `date_amended` (ConceptDate objects)
- `localized_concepts` hash with one LocalizedConcept per language
- Each LocalizedConcept has ConceptData with terms, definition, notes, examples

## Checklist

- [x] Implement TermbaseLoader
- [x] Spec: loads sample termbase entry correctly
- [x] Spec: dates extracted properly
- [x] Spec: multi-language concepts
