# 07 — CLI command + end-to-end run

## Goal

Wire the reconciliation pipeline into a runnable command and execute
it to produce the final dataset.

## Deliverable

Either:
- A new Thor CLI command: `iev reconcile --termbase <path> --output <dir>`
- Or a standalone script: `scripts/reconcile.rb`

The command should:
1. Load termbase.yaml
2. Load live HTML from PageStore
3. Merge + diff
4. Serialize V3 YAML
5. Write register.yaml
6. Report: total concepts, in-both, termbase-only, live-only, amendments detected

## Checklist

- [x] Define command interface
- [x] Implement
- [x] Run end-to-end and verify output
- [x] Spot-check 5 concepts manually (in-both, termbase-only, live-only, with changes)
