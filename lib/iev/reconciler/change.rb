# frozen_string_literal: true

module Iev
  module Reconciler
    # A single field-level difference between the termbase snapshot and
    # the live snapshot of one concept. Collected into a ChangeSet.
    #
    # @attr code [String] IEV code (e.g. "102-01-01")
    # @attr field [Symbol] what changed: :designation, :definition, :notes,
    #   :examples, :status, :language_added, :language_removed
    # @attr language [String, nil] ISO 639-2 code, nil for concept-level
    # @attr old_value [String, nil] termbase value (nil for additions)
    # @attr new_value [String, nil] live value (nil for removals)
    # @attr detected_at [String] ISO 8601 date the change was observed
    Change = Struct.new(:code, :field, :language, :old_value, :new_value,
                        :detected_at, keyword_init: true) do
      def to_h
        {
          code: code,
          field: field.to_s,
          language: language,
          detected_at: detected_at,
          old_value: old_value,
          new_value: new_value,
        }
      end
    end
  end
end
