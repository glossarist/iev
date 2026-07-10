# frozen_string_literal: true

module Iev
  module Reconciler
    # Maps termbase entry_status strings to Glossarist V3 ConceptStatus
    # enum values. Stateless and pure.
    module StatusMapper
      MAP = {
        "Standard" => "valid",
        "Published" => "valid",
        "Effective" => "valid",
        "Draft" => "draft",
        "Not Valid" => "notValid",
        "Superseded" => "superseded",
        "Retired" => "retired",
      }.freeze

      DEFAULT = "valid"

      module_function

      # @param entry_status [String, nil]
      # @return [String] a valid ConceptStatus value
      def call(entry_status)
        MAP[entry_status.to_s] || DEFAULT
      end
    end
  end
end
