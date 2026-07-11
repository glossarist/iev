# frozen_string_literal: true

require "nokogiri"

module Iev
  module Reconciler
    # Indexes live HTML pages and builds Glossarist::ManagedConcept
    # objects on demand per code. Uses Iev::Scraper::PageParser which
    # runs the full semantic enrichment pipeline (HTML → AsciiDoc with
    # stem:[] for math, {{urn:...}} for cross-refs, etc.), so parsed
    # output matches the format used in termbase.yaml.
    class LiveLoader
      # @param pages_dir [String, Pathname] directory containing *.html pages
      def initialize(pages_dir)
        @pages_dir = pages_dir.to_s
        @index = nil
      end

      def codes
        index.keys
      end

      def get(code)
        path = index[code]
        return nil unless path

        html = File.read(path, encoding: "utf-8")
        parse_concept(code, html)
      end

      private

      def index
        @index ||= Dir.glob(File.join(@pages_dir, "*.html")).each_with_object({}) do |path, h|
          h[File.basename(path, ".html")] = path
        end
      end

      def parse_concept(code, html)
        doc = Nokogiri::HTML(html)
        parsed = Iev::Scraper::PageParser.new(doc, code).parse
        return nil unless parsed && parsed.dig("data", "localized_concepts")&.any?

        build_concept(code, parsed["data"]["localized_concepts"])
      end

      def build_concept(code, localized_data)
        concept = Glossarist::ManagedConcept.of_yaml(
          "id" => code, "data" => { "id" => code },
        )
        concept.status = "valid"
        concept.schema_version = "3"

        localized_data.each do |lang, lc_data|
          lc = build_localized_concept(code, lang, lc_data)
          concept.add_l10n(lc)
        end

        concept
      end

      def build_localized_concept(code, lang, lc_data)
        cdata = Glossarist::ConceptData.new
        cdata.id = code
        cdata.language_code = lang
        cdata.entry_status = "valid"

        term = lc_data["term"].to_s
        cdata.terms = if term.empty?
                        []
                      else
                        [Glossarist::Designation::Expression.new(
                          designation: term,
                          normative_status: "preferred",
                        )]
                      end

        definition = lc_data["definition"]
        if definition && !definition.empty?
          parts = split_notes_examples(definition)
          if parts[:definition] && !parts[:definition].empty?
            cdata.definition = [Glossarist::DetailedDefinition.new(content: parts[:definition])]
          end
          cdata.notes = parts[:notes].map { |n| Glossarist::DetailedDefinition.new(content: n) }
          cdata.examples = parts[:examples].map { |e| Glossarist::DetailedDefinition.new(content: e) }
        end

        lc = Glossarist::LocalizedConcept.new
        lc.id = code
        lc.data = cdata
        lc
      end

      NOTE_RE = /^(Note\s+\d+\s+to\s+entry:.*)$/i
      EXAMPLE_RE = /^(Example\s*:.*)$/i

      def split_notes_examples(text)
        notes = []
        examples = []

        lines = text.split("\n")
        definition_lines = []

        lines.each do |line|
          stripped = line.strip
          if stripped.match?(NOTE_RE)
            notes << stripped
          elsif stripped.match?(EXAMPLE_RE)
            examples << stripped
          else
            definition_lines << line
          end
        end

        definition = definition_lines.join("\n").strip
        definition = nil if definition.empty?

        { definition: definition, notes: notes, examples: examples }
      end
    end
  end
end
