# frozen_string_literal: true

require "yaml"

module Iev
  module Reconciler
    # Loads termbase.yaml into a raw hash, then builds
    # Glossarist::ManagedConcept objects on demand per code.
    # This avoids the cost of constructing 22k model objects upfront.
    class TermbaseLoader
      # @param path [String, Pathname] path to termbase.yaml
      def initialize(path)
        @path = path.to_s
        @data = nil
      end

      # @return [Hash<String, Hash>] raw termbase data keyed by code
      def raw
        @data ||= YAML.load_file(@path)
      end

      # @return [Array<String>] all codes in the termbase
      def codes
        raw.keys.map(&:to_s)
      end

      # Build a single ManagedConcept for the given code.
      # @param code [String]
      # @return [Glossarist::ManagedConcept, nil]
      def get(code)
        entry = raw[code] || raw[code.to_sym]
        return nil unless entry.is_a?(Hash)

        build_concept(code.to_s, entry)
      end

      private

      def build_concept(code, entry)
        concept = Glossarist::ManagedConcept.of_yaml(
          "id" => code, "data" => { "id" => code },
        )
        concept.status = concept_status(entry)
        concept.dates = concept_dates(entry)
        concept.schema_version = "3"

        build_localized(code, entry).each do |lc|
          concept.add_l10n(lc)
        end

        concept
      end

      def concept_status(entry)
        lang_data = first_language(entry)
        StatusMapper.call(lang_data&.dig("entry_status"))
      end

      def concept_dates(entry)
        lang_data = first_language(entry)
        return [] unless lang_data

        dates = []
        if lang_data["date_accepted"]
          dates << Glossarist::ConceptDate.new(
            type: "accepted",
            date: lang_data["date_accepted"],
          )
        end
        if lang_data["date_amended"] && lang_data["date_amended"] != lang_data["date_accepted"]
          dates << Glossarist::ConceptDate.new(
            type: "amended",
            date: lang_data["date_amended"],
          )
        end
        dates
      end

      def first_language(entry)
        entry.values.find { |v| v.is_a?(Hash) && v["terms"] }
      end

      def build_localized(code, entry)
        result = []
        entry.each do |lang, data|
          next unless data.is_a?(Hash) && data["terms"]
          lc = build_localized_concept(code, lang, data)
          result << lc if lc
        end
        result
      end

      def build_localized_concept(code, lang, data)
        cdata = Glossarist::ConceptData.new
        cdata.id = code
        cdata.language_code = lang
        cdata.entry_status = StatusMapper.call(data["entry_status"])

        cdata.terms = (data["terms"] || []).map do |t|
          Glossarist::Designation::Expression.new(
            designation: t["designation"],
            normative_status: t["normative_status"] || "preferred",
            type: t["type"] || "expression",
          )
        end

        if data["definition"] && !data["definition"].empty?
          cdata.definition = [Glossarist::DetailedDefinition.new(content: data["definition"])]
        end

        cdata.notes = Array(data["notes"]).map { |n| Glossarist::DetailedDefinition.new(content: n) }
        cdata.examples = Array(data["examples"]).map { |e| Glossarist::DetailedDefinition.new(content: e) }

        lc = Glossarist::LocalizedConcept.new
        lc.id = code
        lc.data = cdata
        lc
      end
    end
  end
end
