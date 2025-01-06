# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module Cli
    class Command < Thor
      include CommandHelper

      desc "xlsx2yaml FILE", "Converts Excel IEV exports to YAMLs."
      def xlsx2yaml(file)
        handle_generic_options(options)
        db = Sequel.sqlite
        DbWriter.new(db).import_spreadsheet(file)
        ds = filter_dataset(db, options)
        collection = build_collection_from_dataset(ds)
        save_collection_to_files(collection, options[:output])
        summary
      end

      desc "xlsx2db FILE", "Imports Excel to SQLite database."
      def xlsx2db(file)
        handle_generic_options(options)
        # Instantiating an in-memory db and dumping it later is faster than
        # just working on file db.
        db = Sequel.sqlite
        DbWriter.new(db).import_spreadsheet(file)
        save_db_to_file(db, options[:output])
        summary
      end

      desc "db2yaml DB_FILE", "Exports SQLite to IEV YAMLs."
      def db2yaml(dbfile)
        handle_generic_options(options)
        db = Sequel.sqlite(dbfile)
        ds = filter_dataset(db, options)
        collection = build_collection_from_dataset(ds)
        save_collection_to_files(collection, options[:output])
        summary
      end

      def self.exit_on_failure?
        true
      end

      # Options must be declared at the bottom because Thor must have commands
      # defined in advance.

      def self.shared_option(name, methods:, **kwargs)
        [*methods].each { |m| option name, for: m, **kwargs }
      end

      shared_option :only_concepts,
                    desc: "Only process concepts with IEVREF matching this argument, " \
                          "'%' and '_' wildcards are supported and have meaning as in SQL " \
                          "LIKE operator",
                    methods: %i[xlsx2yaml db2yaml]

      shared_option :only_languages,
                    desc: "Only export these languages, skip concepts which aren't " \
                          "translated to any of them (comma-separated list, language " \
                          "codes must be as in spreadsheet)",
                    methods: %i[xlsx2yaml db2yaml]

      shared_option :output,
                    desc: "Output directory",
                    aliases: :o,
                    default: Dir.pwd,
                    methods: %i[xlsx2yaml db2yaml]

      shared_option :output,
                    desc: "Output file",
                    aliases: :o,
                    default: File.join(Dir.pwd, "concepts.sqlite3"),
                    methods: :xlsx2db

      shared_option :progress,
                    type: :boolean,
                    desc: "Enables or disables progress indicator. By default disabled " \
                          "when 'CI' environment variable is set and enabled otherwise",
                    methods: %i[xlsx2yaml xlsx2db db2yaml]

      shared_option :debug_term_attributes,
                    desc: "Enables debug messages about term attributes recognition",
                    type: :boolean,
                    default: false,
                    methods: %i[xlsx2yaml db2yaml]

      shared_option :debug_sources,
                    desc: "Enables debug messages about authoritative sources recognition",
                    type: :boolean,
                    default: false,
                    methods: %i[xlsx2yaml db2yaml]

      shared_option :debug_relaton,
                    desc: "Enables debug messages about Relaton integration",
                    type: :boolean,
                    default: false,
                    methods: %i[xlsx2yaml db2yaml]

      shared_option :profile,
                    desc: "Generates profiler reports for this program, requires ruby-prof",
                    type: :boolean,
                    default: false,
                    methods: %i[xlsx2yaml xlsx2db db2yaml]
    end
  end
end
