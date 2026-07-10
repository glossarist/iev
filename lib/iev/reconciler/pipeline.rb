# frozen_string_literal: true

require "date"
require "fileutils"
require "yaml"

module Iev
  module Reconciler
    # Orchestrates the full reconciliation by streaming through codes
    # one at a time. Each code is loaded → merged → serialized → discarded,
    # so memory usage is bounded regardless of dataset size.
    class Pipeline
      attr_reader :stats

      # @param termbase_path [String] path to termbase.yaml
      # @param pages_dir [String] directory with mirrored HTML pages
      # @param output_dir [String] where to write concepts + reports
      # @param detected_at [String] ISO 8601 date for detected changes
      def initialize(termbase_path:, pages_dir:, output_dir:,
                     detected_at: Date.today.iso8601)
        @termbase_path = termbase_path
        @pages_dir = pages_dir
        @output_dir = output_dir
        @detected_at = detected_at
        @stats = {}
      end

      # Run the full pipeline.
      # @return [void]
      def run
        FileUtils.mkdir_p(File.join(@output_dir, "concepts"))
        FileUtils.mkdir_p(File.join(@output_dir, "report"))

        warn "Indexing sources..."
        termbase = TermbaseLoader.new(@termbase_path)
        live = LiveLoader.new(@pages_dir)
        all_codes = (termbase.codes + live.codes).uniq.sort
        warn "  #{termbase.codes.size} termbase + #{live.codes.size} live = #{all_codes.size} total"

        merger = ConceptMerger.new
        reconciled = []

        all_codes.each_with_index do |code, idx|
          rc = merger.merge(
            code: code,
            termbase_concept: termbase.get(code),
            live_concept: live.get(code),
            detected_at: @detected_at,
          )

          if rc
            reconciled << rc
            save_concept(rc.managed_concept)
          end

          if (idx + 1) % 1000 == 0
            warn "  #{idx + 1}/#{all_codes.size}..."
          end
        end

        compute_stats(reconciled)
        Report.new(reconciled).write_to(File.join(@output_dir, "report"))
        warn "Done."
      end

      private

      def save_concept(concept)
        path = File.join(@output_dir, "concepts", "#{concept.id}.yaml")
        parts = [concept.to_yaml]
        (concept.localized_concepts || {}).each_key do |lang|
          lc = concept.localization(lang)
          parts << lc.to_yaml if lc
        end
        File.write(path, parts.join("\n"), encoding: "utf-8")
      end

      def compute_stats(reconciled)
        @stats = {
          total: reconciled.size,
          in_both: reconciled.count { |r| r.source == :both },
          termbase_only: reconciled.count { |r| r.source == :termbase_only },
          live_only: reconciled.count { |r| r.source == :live_only },
          changed: reconciled.count { |r| !r.change_set.empty? },
        }
        warn ""
        warn "Results:"
        warn "  In both (merged):        #{@stats[:in_both]}"
        warn "  Termbase only (retired): #{@stats[:termbase_only]}"
        warn "  Live only (new):         #{@stats[:live_only]}"
        warn "  Concepts with changes:   #{@stats[:changed]}"
        warn "  Total:                   #{@stats[:total]}"
      end
    end
  end
end
