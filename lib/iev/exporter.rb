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
    def initialize(input_path, output_dir: Dir.pwd,
                   only_concepts: nil, only_languages: nil)
      @input_path = Pathname.new(input_path)
      validate_input!

      @output_dir = Pathname.new(output_dir)
      @filters = {
        only_concepts: only_concepts,
        only_languages: only_languages,
      }.compact
    end

    # Run the export pipeline: load → transform → save.
    # @return [Glossarist::ManagedConceptCollection]
    def export
      dataset = load_dataset
      collection = build_collection(dataset)
      save_collection(collection)
      collection
    end

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
      Glossarist::ManagedConceptCollection.new.tap do |collection|
        dataset.each do |row|
          term = TermBuilder.build_from(row)
          next unless term

          concept = collection.fetch_or_initialize(term.id)
          concept.add_l10n(term)
        end
      end
    end

    def save_collection(collection)
      concepts_dir = output_dir.expand_path.join("concepts")
      FileUtils.mkdir_p(concepts_dir)
      collection.save_to_files(concepts_dir.to_s)
    end
  end
end
