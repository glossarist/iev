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
        areas = lc_data["term_areas"] || {}
        cdata.terms = if term.empty?
                        []
                      else
                        TermMarkerParser.parse_multiple(term).map do |parsed|
                          build_expression(parsed, areas[parsed.designation])
                        end
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

      def build_expression(parsed, area = nil)
        expr = Glossarist::Designation::Expression.new(
          designation: parsed.designation,
          normative_status: "preferred",
        )
        expr.geographical_area = area if area
        expr.usage_info = parsed.usage_info if parsed.usage_info
        expr.prefix = parsed.is_prefix if parsed.is_prefix

        grammar = build_grammar_info(parsed)
        expr.grammar_info = [grammar] if grammar
        expr
      end

      def build_related_concepts(parsed)
        return [] unless parsed.related_refs&.any?

        parsed.related_refs.map do |code|
          Glossarist::RelatedConcept.new(
            type: "see",
            ref: { "source" => "IEV", "id" => code },
          )
        end
      end

      def build_grammar_info(parsed)
        has_gender = parsed.genders&.any?
        has_number = parsed.numbers&.any?
        has_pos = !parsed.part_of_speech.nil?
        return nil unless has_gender || has_number || has_pos

        grammar = Glossarist::Designation::GrammarInfo.new
        grammar.gender = parsed.genders if has_gender
        grammar.number = parsed.numbers if has_number
        grammar.part_of_speech = parsed.part_of_speech if has_pos
        grammar
      end

      NOTE_RE = /^(Note\s+\d+\s+to\s+entry:.*)$/i
      EXAMPLE_RE = /^(Example\s*:.*)$/i
      NOTE_PREFIX_RE = /^Note\s+\d+\s+to\s+entry:\s*/i
      EXAMPLE_PREFIX_RE = /^Example\s*:\s*/i

      def split_notes_examples(text)
        notes = []
        examples = []

        lines = text.split("\n")
        definition_lines = []

        lines.each do |line|
          stripped = line.strip
          if stripped.match?(NOTE_RE)
            notes << stripped.sub(NOTE_PREFIX_RE, "")
          elsif stripped.match?(EXAMPLE_RE)
            examples << stripped.sub(EXAMPLE_PREFIX_RE, "")
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
