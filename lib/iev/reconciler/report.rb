# frozen_string_literal: true

require "csv"
require "yaml"

module Iev
  module Reconciler
    # Generates dataset-level change reports from reconciled concepts.
    # Answers "what changed across the entire IEV?" with machine-readable
    # summary files.
    class Report
      # @param reconciled [Array<ReconciledConcept>] all reconciled concepts
      def initialize(reconciled)
        @reconciled = reconciled
      end

      # Write all report files to the given directory.
      # @param dir [String, Pathname]
      def write_to(dir)
        require "fileutils"
        FileUtils.mkdir_p(dir)

        write_summary(File.join(dir, "summary.yaml"))
        write_changes_csv(File.join(dir, "changes.csv"))
        write_retired(File.join(dir, "retired.yaml"))
        write_new_concepts(File.join(dir, "new_concepts.yaml"))
      end

      # @return [Hash] aggregate statistics
      def summary
        {
          total_concepts: @reconciled.size,
          sources: source_counts,
          changes: change_stats,
        }
      end

      private

      def write_summary(path)
        File.write(path, YAML.dump(summary))
      end

      def write_changes_csv(path)
        CSV.open(path, "w") do |csv|
          csv << %w[code section field language detected_at old_value new_value]
          @reconciled.each do |rc|
            rc.change_set.each do |change|
              csv << [
                change.code,
                section_of(change.code),
                change.field,
                change.language,
                change.detected_at,
                truncate(change.old_value),
                truncate(change.new_value),
              ]
            end
          end
        end
      end

      def write_retired(path)
        retired = @reconciled
          .select { |rc| rc.source == :termbase_only && rc.managed_concept }
          .map { |rc| rc.managed_concept.id }
        File.write(path, YAML.dump(retired))
      end

      def write_new_concepts(path)
        new_concepts = @reconciled
          .select { |rc| rc.source == :live_only && rc.managed_concept }
          .map { |rc| rc.managed_concept.id }
        File.write(path, YAML.dump(new_concepts))
      end

      def source_counts
        @reconciled.group_by(&:source).transform_values(&:size)
      end

      def change_stats
        all_changes = @reconciled.flat_map { |rc| rc.change_set.to_a }
        {
          total: all_changes.size,
          by_field: tally_by(all_changes, :field),
          by_language: tally_by(all_changes, :language),
          by_section: tally_by_section(all_changes),
        }
      end

      def tally_by(changes, attr)
        changes
          .group_by { |c| c.send(attr) }
          .transform_values(&:size)
          .sort_by { |_, v| -v }
          .to_h
      end

      def tally_by_section(changes)
        changes
          .group_by { |c| section_of(c.code) }
          .transform_values(&:size)
          .sort_by { |_, v| -v }
          .to_h
      end

      def section_of(code)
        code.to_s.rpartition("-").first
      end

      def truncate(value, max = 200)
        return "" if value.nil?
        value = value.to_s
        value.size > max ? value[0, max] + "..." : value
      end
    end
  end
end
