# 08 — Report

## Goal

Generate dataset-level change reports from the reconciled concepts.
This answers "what changed across the entire IEV?"

## Output files

```
report/
  summary.yaml       # aggregate statistics
  changes.csv        # one row per field-level change
  retired.yaml       # concepts retired since termbase
  new_concepts.yaml  # concepts added since termbase
```

## summary.yaml

```yaml
total_concepts: 23058
sources:
  in_both: 16643
  termbase_only: 5585
  live_only: 830
changes:
  total: 5499
  by_field:
    definition: 4200
    designation: 350
    notes: 580
    examples: 120
    status: 249
  by_language:
    eng: 5000
    fra: 450
    deu: 49
  by_section:
    "113-01": 45
    "102-01": 12
    ...
```

## changes.csv

Columns: `code, section, field, language, detected_at, old_value, new_value`

## Checklist

- [x] Implement Report
- [x] Spec: summary counts correct
- [x] Spec: CSV format correct
- [x] Spec: retired/new lists correct
