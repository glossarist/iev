# 09 — Pipeline

## Goal

Orchestrate the full reconciliation: load → merge → serialize → report.

## Flow

```
Pipeline#run
  ├── TermbaseLoader.load(path) → Hash<code, ManagedConcept>
  ├── LiveLoader.load(dir)      → Hash<code, ManagedConcept>
  ├── for each code in union:
  │     ├── ConceptMerger.merge(code, tb, live) → ReconciledConcept
  │     └── collect ReconciledConcept
  ├── save concepts to output/concepts/*.yaml
  └── Report.new(reconciled).write_to(output/report/)
```

## Checklist

- [x] Implement Pipeline
- [x] Spec: pipeline produces expected output with test fixtures
