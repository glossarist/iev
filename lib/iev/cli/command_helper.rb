# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module Cli
    module CommandHelper
      include Cli::Ui

      protected

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

      def export_progress(current, total)
        return unless $IEV_PROGRESS
        return if total <= 1 # single-row dataset, skip progress

        if current == total
          Ui.info "" # clear progress line
        else
          Ui.progress "Processing #{current}/#{total}..."
        end
      end

      def print_export_summary(stats)
        return unless stats

        s = stats
        elapsed = format_elapsed(s[:elapsed_seconds])
        info "Exported #{s[:concept_count]} concepts " \
             "(#{s[:localized_count]} localized) in #{elapsed}"
      end

      def format_elapsed(seconds)
        if seconds < 60
          "%.1fs" % seconds
        else
          mins = (seconds / 60).to_i
          secs = (seconds % 60).round
          "#{mins}m #{secs}s"
        end
      end

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

      def build_concept_from_raw(code, raw)
        concept = Glossarist::ManagedConcept.of_yaml(
          "id" => code,
          "data" => { "id" => code },
        )

        localized = extract_localized(raw)
        localized.each do |lang, entry|
          l10n = build_localized_concept(code, lang, entry)
          concept.add_l10n(l10n)
        end

        concept
      end

      def extract_localized(raw)
        # Scraper format: raw["data"]["localized_concepts"] => {lang => {term, definition}}
        data = raw["data"]
        if data && data["localized_concepts"]
          return data["localized_concepts"]
        end

        # DataSource format: raw itself, keys are lang codes
        raw.each_with_object({}) do |(k, v), h|
          h[k] = v if v.is_a?(Hash) && v["terms"]
        end
      end

      def build_localized_concept(code, lang, entry)
        terms = if entry["terms"]
                  entry["terms"].map { |t| Glossarist::Designation::Expression.new(**t.transform_keys(&:to_sym)) }
                else
                  [Glossarist::Designation::Expression.new(
                    designation: entry["term"],
                    normative_status: "preferred",
                  )]
                end

        cd = Glossarist::ConceptData.new
        cd.id = code
        cd.language_code = lang
        cd.terms = terms

        definition = entry["definition"]
        if definition
          content = definition.is_a?(String) ? definition : definition
          cd.definition = [Glossarist::DetailedDefinition.new(content: content)]
        end

        l10n = Glossarist::LocalizedConcept.new
        l10n.data = cd
        l10n.id = code
        l10n
      end

      def print_concept_grouped_yaml(concept)
        content = []
        content << concept.to_yaml
        concept.localized_concepts.each_key do |lang|
          content << concept.localization(lang).to_yaml
        end
        puts content.join("\n")
      end
    end
  end
end
