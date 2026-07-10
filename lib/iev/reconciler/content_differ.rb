# frozen_string_literal: true

module Iev
  module Reconciler
    # Compares two Glossarist::ManagedConcept objects and produces a
    # ChangeSet with field-level differences. This powers the change
    # reporting that answers "what changed, from what to what?"
    class ContentDiffer
      # @param old_concept [Glossarist::ManagedConcept] the termbase snapshot
      # @param new_concept [Glossarist::ManagedConcept] the live snapshot
      # @param detected_at [String] ISO 8601 date the change was observed
      # @return [ChangeSet]
      def diff(old_concept, new_concept, detected_at:)
        code = new_concept&.id || old_concept&.id
        change_set = ChangeSet.new(code)

        return change_set unless old_concept && new_concept

        diff_status(change_set, old_concept, new_concept, detected_at)
        diff_languages(change_set, old_concept, new_concept, detected_at)
        diff_localized(change_set, old_concept, new_concept, detected_at)

        change_set
      end

      private

      def diff_status(cs, old_c, new_c, date)
        old_status = old_c.status
        new_status = new_c.status
        return if old_status == new_status

        cs.add(Change.new(
          code: cs.code,
          field: :status,
          language: nil,
          old_value: old_status,
          new_value: new_status,
          detected_at: date,
        ))
      end

      def diff_languages(cs, old_c, new_c, date)
        old_langs = language_keys(old_c)
        new_langs = language_keys(new_c)

        (new_langs - old_langs).each do |lang|
          cs.add(Change.new(
            code: cs.code, field: :language_added, language: lang,
            old_value: nil, new_value: "present", detected_at: date,
          ))
        end

        (old_langs - new_langs).each do |lang|
          cs.add(Change.new(
            code: cs.code, field: :language_removed, language: lang,
            old_value: "present", new_value: nil, detected_at: date,
          ))
        end
      end

      def diff_localized(cs, old_c, new_c, date)
        common_langs = language_keys(old_c) & language_keys(new_c)
        common_langs.each do |lang|
          old_lc = localized_data(old_c, lang)
          new_lc = localized_data(new_c, lang)
          next unless old_lc && new_lc

          diff_designation(cs, lang, old_lc, new_lc, date)
          diff_definition(cs, lang, old_lc, new_lc, date)
          diff_notes(cs, lang, old_lc, new_lc, date)
          diff_examples(cs, lang, old_lc, new_lc, date)
        end
      end

      def diff_designation(cs, lang, old_lc, new_lc, date)
        old_term = extract_designation(old_lc)
        new_term = extract_designation(new_lc)
        return if normalize(old_term) == normalize(new_term)

        cs.add(Change.new(
          code: cs.code, field: :designation, language: lang,
          old_value: old_term, new_value: new_term, detected_at: date,
        ))
      end

      def diff_definition(cs, lang, old_lc, new_lc, date)
        old_def = extract_definition(old_lc)
        new_def = extract_definition(new_lc)
        return if normalize(old_def) == normalize(new_def)

        cs.add(Change.new(
          code: cs.code, field: :definition, language: lang,
          old_value: old_def, new_value: new_def, detected_at: date,
        ))
      end

      def diff_notes(cs, lang, old_lc, new_lc, date)
        old_notes = extract_notes(old_lc)
        new_notes = extract_notes(new_lc)
        return if old_notes == new_notes

        cs.add(Change.new(
          code: cs.code, field: :notes, language: lang,
          old_value: old_notes.join(" | "), new_value: new_notes.join(" | "),
          detected_at: date,
        ))
      end

      def diff_examples(cs, lang, old_lc, new_lc, date)
        old_ex = extract_examples(old_lc)
        new_ex = extract_examples(new_lc)
        return if old_ex == new_ex

        cs.add(Change.new(
          code: cs.code, field: :examples, language: lang,
          old_value: old_ex.join(" | "), new_value: new_ex.join(" | "),
          detected_at: date,
        ))
      end

      # --- extraction helpers ---

      def language_keys(concept)
        concept.localized_concepts&.keys || []
      end

      def localized_data(concept, lang)
        lc = concept.localization(lang)
        lc&.data
      end

      def extract_designation(cdata)
        cdata&.terms&.first&.designation.to_s
      end

      def extract_definition(cdata)
        cdata&.definition&.first&.content.to_s
      end

      def extract_notes(cdata)
        Array(cdata&.notes).map(&:content)
      end

      def extract_examples(cdata)
        Array(cdata&.examples).map(&:content)
      end

      def normalize(str)
        return "" unless str
        str
          .gsub(/<[^>]+>/, "")
          .gsub(/\s+/, " ")
          .gsub(/["""']/, "'")
          .strip
          .downcase
      end
    end
  end
end
