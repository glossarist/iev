# 06 — ContentDiffer

## Goal

Compare two `ManagedConcept` objects and produce a `ChangeSet` with
field-level differences. This is the core of change reporting.

## What to diff

Per localized concept (per language):
- `designation` (term text)
- `definition` (text content)
- `notes` (added/removed/changed)
- `examples` (added/removed/changed)

At concept level:
- `status` (e.g. valid → retired)
- language added (in live but not termbase)
- language removed (in termbase but not live)

## Normalization

Before comparison: strip HTML tags, normalize whitespace, normalize
unicode quotes. Avoid false positives from encoding differences.

## Checklist

- [x] Implement ContentDiffer
- [x] Spec: identical concepts → empty ChangeSet
- [x] Spec: definition changed → one Change
- [x] Spec: language added → one Change
- [x] Spec: status changed → one Change
