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
      figures = FigureBuilder.extract!(collection)
      enrich_references(collection)
      save_collection(collection)
      save_figures(figures)
      save_bibliography(BibliographyBuilder.build(collection))
      save_register
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      @stats = {
        concept_count: collection.count,
        localized_count: localized_count(collection),
        figure_count: figures.length,
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

        # Parse IevCode once per concept — used by all helpers below.
        code = IevCode.new(term.id)

        concept = concept_index[term.id] ||= begin
          c = Glossarist::ManagedConcept.new(data: { "id" => term.id })
          c.uuid = term.id
          c.schema_version = "3"
          c.data.domains = domain_references_for(code)
          c.data.tags = tags_for(code)
          add_section_broader(c, code)
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
      collection.save_grouped_concepts_to_files(concepts_dir.to_s)
    end

    def save_figures(figures)
      return if figures.empty?

      figures_dir = output_dir.expand_path.join("figures")
      FileUtils.mkdir_p(figures_dir)
      figures.each do |figure|
        path = figures_dir.join("#{figure.id}.yaml")
        File.write(path, figure.to_yaml, encoding: "utf-8")
      end
      puts "Written #{figures.length} figures to figures/" if $stdout.tty?
    end

    def save_bibliography(bibliography)
      return if bibliography.entries.empty?

      path = output_dir.expand_path.join("bibliography.yaml")
      FileUtils.mkdir_p(path.dirname)
      File.write(path, bibliography.to_yaml, encoding: "utf-8")
      count = bibliography.entries.length
      puts "Written bibliography.yaml with #{count} entries" if $stdout.tty?
    end

    def enrich_references(collection)
      return if collection.none?

      Glossarist::ConceptEnricher.new.inject_references(collection.to_a)
    end

    def save_register
      areas = SubjectAreas.all
      sections = build_section_tree(areas)

      register = Glossarist::DatasetRegister.new(
        schema_type: "glossarist",
        schema_version: "3",
        id: "iev",
        ref: "IEC 60050:2011",
        year: 2011,
        urn: IEV_SOURCE,
        urn_aliases: ["#{IEV_SOURCE}*"],
        status: "current",
        owner: "IEC",
        source_repo: "https://github.com/glossarist/iev-data",
        tags: %w[electrotechnical vocabulary iec],
        languages: %w[eng fra],
        language_order: %w[eng fra],
        ordering: "systematic",
        sections: sections,
      )

      register_path = output_dir.expand_path.join("register.yaml")
      FileUtils.mkdir_p(register_path.dirname)
      File.write(register_path, register.to_yaml, encoding: "utf-8")
      puts "Written register.yaml with #{sections.length} areas" if $stdout.tty?
    end

    def build_section_tree(areas)
      areas.sort_by { |a| a.code.to_i }.map do |area|
        children = area.sections.sort_by do |s|
          s.code.split("-").map(&:to_i)
        end.map do |sec|
          Glossarist::Section.new(
            id: sec.code,
            names: { "eng" => sec.title },
          )
        end

        Glossarist::Section.new(
          id: area.code,
          names: { "eng" => area.title },
          children: children.empty? ? nil : children,
        )
      end
    end

    def localized_count(collection)
      collection.sum { |c| c.localized_concepts.count }
    end

    # Build domain ConceptReferences for a concept.
    #
    # Per the concept model, ConceptReferenceType distinguishes:
    #   - "domain"  → thematic/subject-area classification (area level)
    #   - "section" → structural section membership (section level)
    #
    # Every concept gets both: a "domain" ref to its area and a "section"
    # ref to its section. Concepts with only an area code (no section)
    # get only a "domain" ref.
    #
    # @param code [IevCode] pre-parsed IEV code
    # @return [Array<Glossarist::ConceptReference>]
    def domain_references_for(code)
      refs = []

      # Domain reference: thematic classification at the area level
      refs << domain_ref(code.area_uri)

      # Section reference: structural membership in the section
      if code.section_code
        refs << section_ref(code.section_uri)
      end

      refs
    end

    # @param code [IevCode] pre-parsed IEV code
    # @return [Array<String>]
    def tags_for(code)
      tags = []
      area = SubjectAreas.find_area(code.area_code)
      tags << area.title if area
      section = code.section_code && SubjectAreas.find_section(code.section_code)
      tags << section.title if section
      tags
    end

    # @param concept [Glossarist::ManagedConcept]
    # @param code [IevCode] pre-parsed IEV code
    def add_section_broader(concept, code)
      return unless code.section_uri

      concept.related ||= []
      return if concept.related.any? do |r|
        r.type == "broader" && r.ref&.id == code.section_uri
      end

      concept.related << Glossarist::RelatedConcept.new(
        type: "broader",
        content: code.section_uri,
        ref: Glossarist::ConceptRef.new(source: "IEV", id: code.section_uri),
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
            ref: Glossarist::ConceptRef.new(source: "IEV", id: child_id),
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
        next if concept.related.any? do |er|
          er.type == r.type && er.ref&.id == r.ref&.id
        end

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

    # --- ConceptReference factory helpers ---

    def domain_ref(concept_id)
      ref = Glossarist::ConceptReference.domain(concept_id)
      ref.source = IEV_SOURCE
      ref
    end

    def section_ref(concept_id)
      ref = Glossarist::ConceptReference.section(concept_id)
      ref.source = IEV_SOURCE
      ref
    end
  end
end
