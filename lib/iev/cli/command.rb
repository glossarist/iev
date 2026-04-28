# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module Cli
    class Command < Thor
      include CommandHelper

      desc "version", "Show iev gem version"
      def version
        puts "iev #{Iev::VERSION}"
      end

      desc "export FILE", "Export IEV data to Glossarist YAML format"
      long_desc <<~DESC
        Exports IEV data from an Excel (.xlsx/.xls) or SQLite (.sqlite3/.sqlite/.db)
        file to Glossarist YAML concept files.

        The input format is detected automatically from the file extension.
      DESC
      option :output, desc: "Output directory", aliases: :o, default: Dir.pwd
      option :only_concepts,
             desc: "Only process concepts with IEVREF matching this pattern " \
                   "(SQL LIKE wildcards: % and _)"
      option :only_languages,
             desc: "Only export these languages, skip concepts which aren't " \
                   "translated to any of them (comma-separated list, language " \
                   "codes must be as in spreadsheet)"
      option :progress, type: :boolean,
                        desc: "Enables or disables progress indicator. By default disabled " \
                              "when 'CI' environment variable is set and enabled otherwise"
      option :profile, type: :boolean, default: false,
                       desc: "Generates profiler reports for this program, requires ruby-prof"
      option :debug_term_attributes, type: :boolean, default: false,
                                     desc: "Enables debug messages about term attributes recognition"
      option :debug_sources, type: :boolean, default: false,
                             desc: "Enables debug messages about authoritative sources recognition"
      option :debug_relaton, type: :boolean, default: false,
                             desc: "Enables debug messages about Relaton integration"
      option :relaton, type: :boolean, default: false,
                       desc: "Fetch source URLs via Relaton (slow, makes network requests)"
      def export(file)
        handle_generic_options(options)

        exporter = Iev::Exporter.new(
          file,
          output_dir: options[:output],
          only_concepts: options[:only_concepts],
          only_languages: options[:only_languages],
          fetch_relaton_links: options[:relaton],
          on_progress: method(:export_progress),
        )
        exporter.export
        print_export_summary(exporter.stats)
      rescue ArgumentError => e
        error e.message
        exit 1
      rescue Sequel::Error => e
        error "Database error: #{e.message}"
        exit 1
      end

      desc "xlsx2yaml FILE", "[DEPRECATED] Use 'export' instead."
      option :output, desc: "Output directory", aliases: :o, default: Dir.pwd
      option :only_concepts,
             desc: "Only process concepts with IEVREF matching this argument, " \
                   "'%' and '_' wildcards are supported and have meaning as in SQL " \
                   "LIKE operator"
      option :only_languages,
             desc: "Only export these languages, skip concepts which aren't " \
                   "translated to any of them (comma-separated list, language " \
                   "codes must be as in spreadsheet)"
      option :progress, type: :boolean,
                        desc: "Enables or disables progress indicator. By default disabled " \
                              "when 'CI' environment variable is set and enabled otherwise"
      option :profile, type: :boolean, default: false,
                       desc: "Generates profiler reports for this program, requires ruby-prof"
      option :debug_term_attributes, type: :boolean, default: false
      option :debug_sources, type: :boolean, default: false
      option :debug_relaton, type: :boolean, default: false
      def xlsx2yaml(file)
        warn "[DEPRECATED] 'xlsx2yaml' is deprecated. Use 'export' instead."
        handle_generic_options(options)

        Iev::Exporter.new(
          file,
          output_dir: options[:output],
          only_concepts: options[:only_concepts],
          only_languages: options[:only_languages],
        ).export

        summary
      end

      desc "db2yaml DB_FILE", "[DEPRECATED] Use 'export' instead."
      option :output, desc: "Output directory", aliases: :o, default: Dir.pwd
      option :only_concepts,
             desc: "Only process concepts with IEVREF matching this argument, " \
                   "'%' and '_' wildcards are supported and have meaning as in SQL " \
                   "LIKE operator"
      option :only_languages,
             desc: "Only export these languages, skip concepts which aren't " \
                   "translated to any of them (comma-separated list, language " \
                   "codes must be as in spreadsheet)"
      option :progress, type: :boolean,
                        desc: "Enables or disables progress indicator. By default disabled " \
                              "when 'CI' environment variable is set and enabled otherwise"
      option :profile, type: :boolean, default: false,
                       desc: "Generates profiler reports for this program, requires ruby-prof"
      option :debug_term_attributes, type: :boolean, default: false
      option :debug_sources, type: :boolean, default: false
      option :debug_relaton, type: :boolean, default: false
      def db2yaml(dbfile)
        warn "[DEPRECATED] 'db2yaml' is deprecated. Use 'export' instead."
        handle_generic_options(options)

        Iev::Exporter.new(
          dbfile,
          output_dir: options[:output],
          only_concepts: options[:only_concepts],
          only_languages: options[:only_languages],
        ).export

        summary
      end

      desc "xlsx2db FILE", "Imports Excel to SQLite database."
      option :output, desc: "Output file", aliases: :o,
                      default: File.join(Dir.pwd, "concepts.sqlite3")
      option :progress, type: :boolean,
                        desc: "Enables or disables progress indicator. By default disabled " \
                              "when 'CI' environment variable is set and enabled otherwise"
      option :profile, type: :boolean, default: false,
                       desc: "Generates profiler reports for this program, requires ruby-prof"
      def xlsx2db(file)
        handle_generic_options(options)
        db = Sequel.sqlite
        DbWriter.new(db).import_spreadsheet(file)
        save_db_to_file(db, options[:output])
        summary
      end

      desc "fetch CODE", "Fetch an IEV concept and output YAML to stdout."
      option :scrape, type: :boolean, default: false,
                      desc: "Scrape from Electropedia instead of using cached data"
      def fetch(code)
        raw = if options[:scrape]
                Scraper.new.fetch_concept(code)
              else
                DataSource.fetch_concept(code)
              end

        concept = build_concept_from_raw(code, raw)
        print_concept_grouped_yaml(concept)
      rescue Iev::DataSource::NotFoundError
        error "IEV concept not found: #{code}"
        exit 1
      rescue Ferrum::Error => e
        error "Scraping failed: #{e.message}"
        exit 1
      end

      def self.exit_on_failure?
        true
      end
    end
  end
end
