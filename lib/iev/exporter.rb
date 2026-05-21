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
      build_section_narrower_relations(collection) if @include_areas
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
          c.uuid = term.id
          c.data.domains = domain_references_for(term.id)
          add_section_broader(c, term.id)
          collection.store(c)
          c
        end
        concept.add_l10n(term)

        promote_supersession(concept, term)
        set_managed_status(concept, term)
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

    IEV_SOURCE = "urn:iec:std:iec:60050"

    def domain_references_for(ievref)
      code = IevCode.new(ievref.to_s)
      refs = []
      if code.area_code
        refs << Glossarist::ConceptReference.new(
          concept_id: code.area_uri,
          source: IEV_SOURCE,
          ref_type: "domain",
        )
      end
      if code.section_code
        refs << Glossarist::ConceptReference.new(
          concept_id: code.section_uri,
          source: IEV_SOURCE,
          ref_type: "domain",
        )
      end
      refs
    end

    def add_section_broader(concept, ievref)
      code = IevCode.new(ievref.to_s)
      return unless code.section_uri

      concept.related ||= []
      return if concept.related.any? do |r|
        r.type == "broader" && r.ref&.id == code.section_uri
      end

      concept.related << Glossarist::RelatedConcept.new(
        type: "broader",
        content: code.section_uri,
        ref: Glossarist::Citation.new(source: "IEV", id: code.section_uri),
      )
    end

    def build_section_narrower_relations(collection)
      mc_index = collection.each_with_object({}) do |c, h|
        h[c.data&.id] = c if c.data&.id
      end

      section_children = {}
      mc_index.each_key do |concept_id|
        code = IevCode.new(concept_id)
        next unless code.section_uri

        (section_children[code.section_uri] ||= []) << concept_id
      end

      section_children.each do |section_uri, child_ids|
        section_mc = mc_index[section_uri]
        next unless section_mc

        narrower = child_ids.sort.map do |child_id|
          Glossarist::RelatedConcept.new(
            type: "narrower",
            content: child_id,
            ref: Glossarist::Citation.new(source: "IEV", id: child_id),
          )
        end

        section_mc.related ||= []
        section_mc.related.concat(narrower)
      end
    end

    # Promote supersedes relations from localized ConceptData to managed level.
    # Supersession is language-independent (REPLACES column is per-concept).
    def promote_supersession(concept, term)
      related = term.data&.related
      return unless related&.any?

      concept.related ||= []
      related.each do |r|
        next if concept.related.any? { |er| er.type == r.type && er.ref&.id == r.ref&.id }

        concept.related << r
      end
      term.data.related = nil
    end

    # Derive managed concept status from the localization's entry_status.
    def set_managed_status(concept, term)
      return if concept.status

      status = term.entry_status
      concept.status = status if status && !status.empty?
    end
  end
end
