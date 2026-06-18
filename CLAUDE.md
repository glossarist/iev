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

- `TermBuilder` — the core converter that turns a spreadsheet row into a `Glossarist::LocalizedConcept`. Handles definition splitting (notes/examples extraction), term designation parsing, and source parsing. Sets `ConceptData#domain` to section/area title text (not URI).
- `SourceParser` — parses the SOURCE column from IEV exports, normalizing references (CEI→IEC, UIT→ITU, etc.) and extracting ref/clause/relationship using extensive regex matching.
- `TermAttrsParser` — parses the TERMATTRIBUTE field (gender, plurality, part of speech, geographical area, usage_info).
- `SupersessionParser` — parses the REPLACES field for deprecated term relationships.
- `SubjectAreas` — manages the IEV subject area/section hierarchy. Bundled `data/subject_areas.yaml` contains the area/section tree. URI scheme: `area-{code}` and `section-{code}`.
- `SubjectAreaConcepts` — builds area and section hierarchy concepts. Uses `ConceptReference` with proper `ref_type` per `ConceptReferenceType`: `"domain"` for thematic area classification, `"section"` for structural section membership. Sets `ConceptData#domain` to area title text.
- `Exporter` — full export pipeline (Excel/SQLite → Glossarist YAML). Assigns domain and section `ConceptReference` objects via `domain_references_for`. Uses `Glossarist::DatasetRegister` model for `register.yaml`. Sets `schema_version: "3"` on all exported concepts. Pipeline order: build → subject areas → section relations → figure extraction → reference enrichment → save concepts → save figures → save bibliography → save register.
- `FigureBuilder` — destructive extraction pass that hoists AsciiDoc image macros (emitted from SIMG tags by `Utilities`) into dataset-shared `Glossarist::Figure` entities. Rewrites inline text to `{{fig:id, display}}` mentions and adds `FigureReference` entries to `ManagedConceptData#figures`. One Figure entity per unique image file; captions merge across languages.
- `BibliographyBuilder` — collects unique `(source, id)` pairs from every concept's sources (localized and managed) into a `Glossarist::BibliographyData`. Entry ids are normalized with the same rules as `Glossarist::Validation::BibliographyIndex` so consumers can resolve anchors.
- `Converter::MathmlToAsciimath` — converts MathML markup to AsciiMath using Plurimath.
- `Utilities` — HTML processing: converts IEV cross-references (`<a href=IEV...>`) to `{{URN, term}}` format (ID first, display text last), handles figures, images, bold tags, and newline normalization.

### Domain/Section Model

Per the concept model's `ConceptReferenceType`:
- `"domain"` — thematic/subject-area classification (area level, e.g. "103")
- `"section"` — structural section membership (section level, e.g. "103-01")

Each concept's `ManagedConceptData#domains` contains both refs. `ConceptData#domain` (a `LocalizedString`) holds the section/area title text. The `ManagedConcept#related` array holds `broader`/`narrower` relationships for the hierarchy tree.

### V3 Output Artifacts

An export produces these files alongside the concepts/ directory:
- `register.yaml` — `Glossarist::DatasetRegister` with section tree, languages, owner, URN.
- `bibliography.yaml` — single `bibliography:` key wrapping an array of `BibliographyEntry` objects. Entry `id` is the normalized anchor that `Glossarist::Validation::BibliographyIndex` will resolve against.
- `figures/{fig-id}.yaml` — one `Glossarist::Figure` per unique image. Each concept carries a `FigureReference` on `ManagedConceptData#figures` and an inline `{{fig:id, display}}` mention in the text where the figure appeared.
- References on localized concepts are populated by `Glossarist::ConceptEnricher#inject_references`, which scans text for `{{urn:...}}`, `<<xref>>`, and `image::` patterns.

### Configuration

`Iev.configure` yields a `Config` object with:
- `data_path` — local path to YAML concept files (env: `IEV_DATA_PATH`)
- `cache_dir` — cache directory (env: `IEV_CACHE_DIR`, default: system tmpdir)
- `remote_base_url` — base URL for remote concept YAML fetching

## Key Conventions

- Ruby >= 3.1.0 required
- All constants live under `Iev::` namespace (e.g. `Iev::IEV_SOURCE`, not top-level `IEV_SOURCE`)
- `Iev.config` / `Iev.configure` / `Iev.reset_config!` are defined directly in `lib/iev.rb` — they must be available at load time without triggering autoload
- `plurimath` and `unitsml` are optional runtime dependencies — loaded with `rescue LoadError`, so the `DataSource`/`Db` APIs work without them
- The IEV Excel export format is specific to IEC-internal use; column structure is documented in README.adoc
- Language codes: the spreadsheet uses ISO 639-1 (2-char like "en"), internally converted to ISO 639-2/3 (3-char like "eng") via `Iso639Code` and `DataConversions`
- `DataConversions` is a refinement (`using DataConversions`) that adds `.sanitize` and `.decode_html` methods to String
- `IevCode` is the single source of truth for IEV code decomposition — always use it instead of manual `split("-")` parsing
- Schema version 3: all exported concepts use `schema_version: "3"`, which supports `annotations`, V3 concept sources, and structured references
