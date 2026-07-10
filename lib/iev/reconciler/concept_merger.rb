# frozen_string_literal: true

require "date"

module Iev
  module Reconciler
    # Merges a termbase concept and a live concept into a single
    # ReconciledConcept. The merge preserves lifecycle dates from the
    # termbase, uses live content for current values, and records any
    # detected changes as ConceptDate amendments.
    #
    # The termbase concept is mutated in place — the pipeline streams
    # through codes one at a time, so each concept object is used once
    # and discarded. This avoids the cost of cloning 20k+ model objects.
    class ConceptMerger
      # @param differ [ContentDiffer] injectable for testing
      def initialize(differ: ContentDiffer.new)
        @differ = differ
      end

      # @param code [String] IEV code
      # @param termbase_concept [Glossarist::ManagedConcept, nil]
      # @param live_concept [Glossarist::ManagedConcept, nil]
      # @param detected_at [String] ISO 8601 date
      # @return [ReconciledConcept]
      def merge(code:, termbase_concept:, live_concept:, detected_at:)
        if termbase_concept && live_concept
          merge_both(code, termbase_concept, live_concept, detected_at)
        elsif termbase_concept
          retire(code, termbase_concept, detected_at)
        else
          ReconciledConcept.new(
            managed_concept: live_concept,
            change_set: ChangeSet.new(code),
            source: :live_only,
          )
        end
      end

      private

      def merge_both(code, tb_concept, live_concept, detected_at)
        change_set = @differ.diff(tb_concept, live_concept, detected_at: detected_at)

        merge_localized_content(tb_concept, live_concept)

        unless change_set.empty?
          add_date(tb_concept, "amended", detected_at)
        end

        ReconciledConcept.new(
          managed_concept: tb_concept,
          change_set: change_set,
          source: :both,
        )
      end

      def retire(code, tb_concept, detected_at)
        tb_concept.status = "retired"
        add_date(tb_concept, "retired", detected_at)

        cs = ChangeSet.new(code)
        cs.add(Change.new(
          code: code, field: :status, language: nil,
          old_value: tb_concept.status, new_value: "retired",
          detected_at: detected_at,
        ))

        ReconciledConcept.new(
          managed_concept: tb_concept,
          change_set: cs,
          source: :termbase_only,
        )
      end

      def merge_localized_content(merged, live_concept)
        live_concept.localized_concepts&.each_key do |lang|
          live_lc = live_concept.localization(lang)
          next unless live_lc&.data

          existing = merged.localization(lang)
          if existing&.data
            update_from_live(existing.data, live_lc.data)
          else
            merged.add_l10n(live_lc)
          end
        end
      end

      def update_from_live(target_data, live_data)
        target_data.definition = live_data.definition if live_data.definition&.any?
        target_data.notes = live_data.notes if live_data.notes&.any?
        target_data.examples = live_data.examples if live_data.examples&.any?
        target_data.terms = live_data.terms if live_data.terms&.any?
      end

      def add_date(concept, type, date)
        concept.dates ||= []
        concept.dates << Glossarist::ConceptDate.new(type: type, date: date)
      end
    end
  end
end
