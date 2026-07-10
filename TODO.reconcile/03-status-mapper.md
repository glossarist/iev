# 03 — StatusMapper

## Goal

Map termbase `entry_status` strings to Glossarist V3 `ConceptStatus`
enum values. Stateless, single responsibility.

## Mapping

| Termbase | V3 |
|----------|-----|
| Standard / Published / Effective | valid |
| Draft | draft |
| Not Valid | notValid |
| Superseded | superseded |
| Retired | retired |

Unknown values default to `valid`.

## Checklist

- [x] Implement StatusMapper
- [x] Spec: all mapped values
- [x] Spec: unknown defaults to valid
