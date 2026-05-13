# frozen_string_literal: true

module Iev
  # Exports IEV data to Glossarist YAML format.
  #
  # Automatically detects input format from file extension:
  #   .xlsx / .xls   → Excel IEV export
  #   .sqlite3 / .sqlite / .db → SQLite database
  #
  # @example Programmatic usage
  #   exporter = Iev::Exporter.new("data.xlsx", output_dir: "/tmp/output")
  #   collection = exporter.export
  #
  # @example With filters
  #   Iev::Exporter.new("data.sqlite3",
  #     output_dir: "/tmp/output",
  #     only_concepts: "103-%",
  #     only_languages: "en,fr",
  #   ).export
  class Exporter
    XLSX_EXTENSIONS = %w[.xlsx .xls].freeze
    SQLITE_EXTENSIONS = %w[.sqlite3 .sqlite .db].freeze

    attr_reader :input_path, :output_dir, :filters

    # @param input_path [String, Pathname] path to Excel or SQLite file
    # @param output_dir [String, Pathname] destination for YAML files
    # @param only_concepts [String, nil] SQL LIKE pattern for IEVREF filtering
    # @param only_languages [String, nil] comma-separated language codes
    # @param fetch_relaton_links [Boolean] fetch source URLs via Relaton
    # @param include_areas [Boolean] create area/section hierarchy concepts
    # @param on_progress [Proc, nil] callback (current, total) during build
    def initialize(input_path, output_dir: Dir.pwd,
                   only_concepts: nil, only_languages: nil,
                   fetch_relaton_links: false,
                   include_areas: true,
                   on_progress: nil)
      @input_path = Pathname.new(input_path)
      validate_input!

      @output_dir = Pathname.new(output_dir)
      @fetch_relaton_links = fetch_relaton_links
      @include_areas = include_areas
      @on_progress = on_progress
      @filters = {
        only_concepts: only_concepts,
        only_languages: only_languages,
      }.compact
    end

    # Run the export pipeline: load → transform → save.
    # @return [Glossarist::ManagedConceptCollection]
    def export
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      dataset = load_dataset
      collection = build_collection(dataset)
      add_subject_area_concepts(collection) if @include_areas
      save_collection(collection)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      @stats = {
        concept_count: collection.count,
        localized_count: localized_count(collection),
        elapsed_seconds: elapsed,
      }
      collection
    end

    # @return [Hash, nil] stats from last export, or nil if export hasn't run
    attr_reader :stats

    private

    def supported_format?
      ext = input_path.extname.downcase
      XLSX_EXTENSIONS.include?(ext) || SQLITE_EXTENSIONS.include?(ext)
    end

    def validate_input!
      unless input_path.exist?
        raise ArgumentError, "Input file not found: #{input_path}"
      end

      return if supported_format?

      exts = (XLSX_EXTENSIONS + SQLITE_EXTENSIONS).join(", ")
      raise ArgumentError,
        "Unsupported format: #{input_path.extname}. Supported: #{exts}"
    end

    def input_format
      ext = input_path.extname.downcase
      XLSX_EXTENSIONS.include?(ext) ? :xlsx : :sqlite
    end

    def load_dataset
      case input_format
      when :xlsx then load_from_xlsx
      when :sqlite then load_from_sqlite
      end
    end

    def load_from_xlsx
      require "creek"
      db = Sequel.sqlite
      DbWriter.new(db).import_spreadsheet(input_path.to_s)
      apply_filters(db)
    end

    def load_from_sqlite
      apply_filters(Sequel.sqlite(input_path.to_s))
    end

    def apply_filters(db)
      query = db[:concepts]
      if filters[:only_concepts]
        query = query.where(Sequel.ilike(:ievref, filters[:only_concepts]))
      end
      if filters[:only_languages]
        query = query.where(language: filters[:only_languages].split(","))
      end
      query
    end

    def build_collection(dataset)
      SourceParser.relaton_enabled = @fetch_relaton_links

      # Use a hash index for O(1) concept lookup instead of
      # Glossarist's O(n) fetch_or_initialize which does linear scan.
      concept_index = {}
      collection = Glossarist::ManagedConceptCollection.new
      row_count = dataset.count
      current = 0

      dataset.each do |row|
        current += 1
        @on_progress&.call(current, row_count)

        term = TermBuilder.build_from(row)
        next unless term

        concept = concept_index[term.id] ||= begin
          c = Glossarist::ManagedConcept.new(data: { "id" => term.id })
          c.data.domains = domain_references_for(term.id)
          collection.store(c)
          c
        end
        concept.add_l10n(term)
      end

      collection
    ensure
      SourceParser.relaton_enabled = true
    end

    def add_subject_area_concepts(collection)
      SubjectAreaConcepts.add_to(collection)
    end

    def save_collection(collection)
      concepts_dir = output_dir.expand_path.join("concepts")
      FileUtils.mkdir_p(concepts_dir)
      collection.save_to_files(concepts_dir.to_s)
    end

    def localized_count(collection)
      collection.sum { |c| c.localized_concepts.count }
    end

    def domain_references_for(ievref)
      parts = ievref.to_s.split("-")
      return [] unless parts.length >= 2

      [
        SubjectAreas.area_uri(parts[0]),
        SubjectAreas.section_uri(parts[0..1].join("-")),
      ].map { |id| Glossarist::ConceptReference.domain(id) }
    end
  end
end
