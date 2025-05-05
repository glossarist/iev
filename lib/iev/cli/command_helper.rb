# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module Cli
    module CommandHelper
      include Cli::Ui

      protected

      def save_collection_to_files(collection, output_dir)
        Profiler.measure("writing-yamls") do
          info "Writing concepts to files..."
          path = File.expand_path("./concepts", output_dir)
          FileUtils.mkdir_p(path)
          collection.save_to_files(path)
        end
      end

      # NOTE: Implementation examples here:
      # https://www.rubydoc.info/github/luislavena/sqlite3-ruby/SQLite3/Backup
      def save_db_to_file(src_db, dbfile)
        info "Saving database to a file..."
        src_db.synchronize do |src_conn|
          dest_conn = SQLite3::Database.new(dbfile)
          b = SQLite3::Backup.new(dest_conn, "main", src_conn, "main")
          b.step(-1)
          b.finish
        end
      end

      def summary
        info "Done!"
      end

      def collection_file_path(file, output_dir)
        output_dir.join(Pathname.new(file).basename.sub_ext(".yaml"))
      end

      # Handles various generic options, e.g. detailed debug switches.
      # Assigns some global variables accordingly, so these settings are
      # available throughout the program.
      def handle_generic_options(options)
        $IEV_PROFILE = options[:profile]
        $IEV_PROGRESS = options.fetch(:progress, !ENV["CI"])

        $IEV_DEBUG = options.to_h
          .select { |k, _| k.to_s.start_with? "debug_" }
          .transform_keys do |k|
          k.to_s.sub("debug_",
                     "").to_sym
        end
      end

      def filter_dataset(db, options)
        query = db[:concepts]

        if options[:only_concepts]
          query = query.where(Sequel.ilike(:ievref,
                                           options[:only_concepts]))
        end

        query = query.where(language: options[:only_languages].split(",")) if options[:only_languages]

        query
      end

      def build_collection_from_dataset(dataset)
        Profiler.measure("building-collection") do
          Glossarist::ManagedConceptCollection.new.tap do |concept_collection|
            dataset.each do |row|
              term = TermBuilder.build_from(row)
              next unless term

              concept = concept_collection.fetch_or_initialize(term.id)
              concept.add_l10n(term)
            end
          end
        end
      end
    end
  end
end
