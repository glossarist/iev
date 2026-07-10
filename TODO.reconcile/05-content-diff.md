# 05 — Content diff detector

## Goal

Detect content changes between the termbase snapshot and the live HTML
for concepts that exist in both sources. Each detected change becomes
an amendment record.

## What to diff

Per localized concept (per language):

1. **Designations** (terms): added, removed, or changed text
2. **Definition**: text content changed
3. **Notes**: added, removed, or changed
4. **Examples**: added, removed, or changed

## Output

For each changed field, record:

```ruby
{
  field: :definition,
  language: :eng,
  old_value: "...",      # from termbase
  new_value: "...",      # from live
  changed_at: MIRROR_DATE # the date we captured the live page
}
```

These feed into the merger to append `ConceptDate(type: amended)` and
optionally an annotation describing the change.

## Approach

String normalization before comparison: strip whitespace, normalize
unicode, ignore case-only differences in designation. Real semantic
diffs (definition rewrite) vs cosmetic diffs (encoding fix).

## Checklist

- [x] Define diff strategy
- [x] implement ContentDiff
- [x] Test: identical → no change; modified definition → one diff
