# 03 — Live HTML loader

## Goal

Load the mirrored HTML pages from `iev-data-latest/pages/` using the
existing `Iev::Scraper::PageParser` to extract structured concept data.

## Source

17,473 HTML pages at `../iev-data-latest/pages/*.html`. Each page is
the current Electropedia display page for one IEV code.

## Deliverable

Class: `Iev::Reconciler::LiveLoader`

- Walks `Iev::Fetcher::PageStore#each_concept`.
- For each page, uses `Iev::Scraper::PageParser` to parse into the raw
  hash that `build_concept_from_raw` expects.
- Returns a Hash keyed by IEV code → parsed raw hash.
- Extracts the publication date from the HTML (e.g. "Publication date:
  2008-08") for concepts not in termbase.

## Checklist

- [x] Define LiveLoader interface
- [x] Implement
- [x] Test: sample page parses with expected localized_concepts
