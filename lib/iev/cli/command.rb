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

      desc "subject_areas",
           "Fetch IEV subject areas and sections from Electropedia."
      option :output, desc: "Output YAML file (default: stdout)", aliases: :o
      option :refresh, type: :boolean, default: false,
                       desc: "Force re-fetch even if cached"
      def subject_areas
        if options[:refresh]
          cache_path = File.join(Iev.config.cache_dir, "subject_areas.yaml")
          FileUtils.rm_f(cache_path)
        end

        result = Iev::SubjectAreas.fetch

        yaml = YAML.dump(result)
        if options[:output]
          File.write(options[:output], yaml, encoding: "utf-8")
          puts "Written to #{options[:output]}"
        else
          puts yaml
        end
      rescue Iev::SubjectAreas::FetchError => e
        error e.message
        exit 1
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

      desc "mirror", "Mirror Electropedia concept pages to local cache"
      option :area,    desc: "Only fetch this subject area (e.g. 102)"
      option :section, desc: "Only fetch this section (e.g. 102-01)"
      option :limit, type: :numeric,
                     desc: "Cap on concepts fetched this run"
      option :refresh, type: :boolean, default: false,
                       desc: "Re-fetch cached pages"
      option :delay, type: :numeric, default: Iev::Fetcher::Mirror::FETCH_DELAY,
                     desc: "Seconds between fetches (mean)"
      option :jitter, type: :numeric,
                      default: Iev::Fetcher::Mirror::DEFAULT_JITTER,
                      desc: "±fraction of delay to randomize each sleep"
      def mirror
        scope = build_fetch_scope
        mirror = Iev::Fetcher::Mirror.new(
          scope: scope,
          options: Iev::Fetcher::Mirror::Options.new(**mirror_options),
        )
        mirror.run
        info "Mirror complete: #{mirror.fetched} concepts fetched."
      rescue Iev::Fetcher::Waf::Error => e
        error "WAF: #{e.message}"
        exit 1
      end

      desc "reparse", "Parse cached HTML into Glossarist YAML concept files"
      option :output, aliases: :o,
                      default: File.join(Dir.pwd, "concepts"),
                      desc: "Output directory"
      option :area,    desc: "Only emit concepts in this area"
      option :section, desc: "Only emit concepts in this section"
      def reparse
        scope = build_fetch_scope
        concepts_dir = build_reparse_dir(options[:output])
        collection = Glossarist::ManagedConceptCollection.new
        each_cached_concept(scope) { |c, raw| collection.store(c) if raw }
        collection.save_grouped_concepts_to_files(concepts_dir.to_s)
        info "Reparsed #{collection.count} concepts into #{concepts_dir}."
      end

      def self.exit_on_failure?
        true
      end

      private

      def build_fetch_scope
        if options[:section]
          Iev::Fetcher::Scope.for_section(options[:section])
        elsif options[:area]
          Iev::Fetcher::Scope.for_area(options[:area])
        else
          Iev::Fetcher::Scope.all
        end
      end

      def mirror_options
        {
          limit: options[:limit],
          refresh: options[:refresh],
          delay: options[:delay],
          jitter: options[:jitter],
          on_progress: method(:mirror_progress),
        }
      end

      def build_reparse_dir(output)
        concepts_dir = Pathname.new(output).expand_path.join("concepts")
        FileUtils.mkdir_p(concepts_dir)
        concepts_dir
      end

      def each_cached_concept(scope)
        store = Iev::Fetcher::PageStore.new
        store.each_concept(scope: scope).each do |code, html|
          doc = Nokogiri::HTML(html)
          raw = Iev::Scraper::PageParser.new(doc, code).parse
          yield build_concept_from_raw(code, raw), raw if raw
        end
      end

      def mirror_progress(_section_idx, _total_sections, _code, status)
        marker = case status
                 when :ok then "+"
                 when :skipped then "."
                 when :not_found, :invalid then "?"
                 when :waf_blocked then "x"
                 when :section_done then "\n"
                 else " "
                 end
        $stdout.write(marker)
        $stdout.flush
      end
    end
  end
end
