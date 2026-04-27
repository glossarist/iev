# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

- Run all tests: `bundle exec rake` or `bundle exec rspec`
- Run a single test file: `bundle exec rspec spec/iev/term_builder_spec.rb`
- Run a single test example: `bundle exec rspec spec/iev/term_builder_spec.rb:42`
- Lint: `bundle exec rubocop`
- CI uses the shared `metanorma/ci` generic-rake workflow

## Architecture

This is a Ruby gem (`iev`) for working with the International Electrotechnical Vocabulary (IEV) from IEC Electropedia. It is part of the Glossarist ecosystem and depends on the `glossarist` gem for concept modeling.

### Two Main Data Flows

**1. Fetching terms (API usage):** `Iev.get(code, lang)` or `Iev.fetch_concept(code)`
- `DataSource` checks a local path (`IEV_DATA_PATH` env var) for YAML concept files, then falls back to fetching from a remote GitHub repo (`glossarist/glossarist-data-iev`), with file-based caching in `IEV_CACHE_DIR` (defaults to system tmpdir).
- `Db` wraps `DataSource` with a two-tier cache (global + local) using `DbCache`, which stores versioned XML files on disk.

**2. Converting Excel exports (CLI usage):** via `exe/iev` (Thor-based)
- `xlsx2yaml`: Excel → `DbWriter` (in-memory SQLite) → `TermBuilder` (row-by-row) → `Glossarist::LocalizedConcept` objects → YAML concept files
- `xlsx2db`: Excel → `DbWriter` → SQLite file
- `db2yaml`: SQLite → `TermBuilder` → YAML concept files

### Key Modules

- `TermBuilder` — the core converter that turns a spreadsheet row into a `Glossarist::LocalizedConcept`. Handles definition splitting (notes/examples extraction), term designation parsing, and source parsing.
- `SourceParser` — parses the SOURCE column from IEV exports, normalizing references (CEI→IEC, UIT→ITU, etc.) and extracting ref/clause/relationship using extensive regex matching.
- `TermAttrsParser` — parses the TERMATTRIBUTE field (gender, plurality, part of speech, geographical area, abbreviations).
- `SupersessionParser` — parses the REPLACES field for deprecated term relationships.
- `Converter::MathmlToAsciimath` — converts MathML markup to AsciiMath using Plurimath.
- `Utilities` — HTML processing: converts IEV cross-references (`<a href=IEV...>`) to `{{term, IEV:code}}` format, handles figures, images, bold tags, and newline normalization.

### Configuration

`Iev.configure` yields a `Config` object with:
- `data_path` — local path to YAML concept files (env: `IEV_DATA_PATH`)
- `cache_dir` — cache directory (env: `IEV_CACHE_DIR`, default: system tmpdir)
- `remote_base_url` — base URL for remote concept YAML fetching

## Key Conventions

- Ruby >= 3.1.0 required
- `plurimath` and `unitsml` are optional runtime dependencies — loaded with `rescue LoadError`, so the `DataSource`/`Db` APIs work without them
- The IEV Excel export format is specific to IEC-internal use; column structure is documented in README.adoc
- Language codes: the spreadsheet uses ISO 639-1 (2-char like "en"), internally converted to ISO 639-2/3 (3-char like "eng") via `Iso639Code` and `DataConversions`
- `DataConversions` is a refinement (`using DataConversions`) that adds `.sanitize` and `.decode_html` methods to String
