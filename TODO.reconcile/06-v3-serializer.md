# 06 — V3 serializer

## Goal

Serialize the merged `ManagedConcept` objects into Glossarist V3 YAML
files using the existing `Glossarist::ManagedConceptCollection` API.

## Output

```
output/
  concepts/
    concept-102-01-01.yaml
    concept-102-01-02.yaml
    ...
  register.yaml          # DatasetRegister
```

Each concept file uses `schema_version: "3"` and the V3 field names
from the concept model:

```yaml
---
schema_version: "3"
identifier: "102-01-01"
status: valid
dates:
  - type: accepted
    date: "2008-08-01"
  - type: amended
    date: "2008-08-01"
localized_concepts:
  eng: ...
  fra: ...
related: ...
```

## Checklist

- [x] Define output layout
- [x] Implement V3 serializer (reuse ManagedConceptCollection#save)
- [x] Test: round-trip — load output back, verify fields
