# 10 — Script wrapper + end-to-end run

## Goal

Rewrite `scripts/reconcile.rb` as a thin wrapper around the library
code. Then run the full pipeline and verify output.

## Checklist

- [x] Rewrite scripts/reconcile.rb as thin wrapper
- [x] Run end-to-end pipeline
- [x] Verify concepts/*.yaml output
- [x] Verify report/*.yaml output
- [x] Spot-check 5 concepts (in-both, retired, new, with changes)
- [x] Spot-check report accuracy
