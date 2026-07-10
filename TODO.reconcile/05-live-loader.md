# 05 — LiveLoader

## Goal

Load live HTML pages and build `Glossarist::ManagedConcept` objects
using the existing `Iev::Scraper::PageParser`.

## Input

`iev-data-latest/pages/*.html` — 17,473 current Electropedia pages.

## Output

`Hash<String, Glossarist::ManagedConcept>` keyed by IEV code.

## Checklist

- [x] Implement LiveLoader
- [x] Spec: parses sample HTML page
- [x] Spec: skips placeholder pages (no localized_concepts)
