# frozen_string_literal: true

require "nokogiri"

module Iev
  module Reconciler
    # Indexes live HTML pages and builds Glossarist::ManagedConcept
    # objects on demand per code.
    class LiveLoader
      # @param pages_dir [String, Pathname] directory containing *.html pages
      def initialize(pages_dir)
        @pages_dir = pages_dir.to_s
        @index = nil
      end

      # @return [Array<String>] all codes with cached HTML pages
      def codes
        index.keys
      end

      # Build a single ManagedConcept for the given code.
      # @param code [String]
      # @return [Glossarist::ManagedConcept, nil]
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
          parsed = split_definition(definition)
          if parsed[:definition] && !parsed[:definition].empty?
            cdata.definition = [Glossarist::DetailedDefinition.new(content: parsed[:definition])]
          end
          cdata.notes = parsed[:notes].map { |n| Glossarist::DetailedDefinition.new(content: n) }
          cdata.examples = parsed[:examples].map { |e| Glossarist::DetailedDefinition.new(content: e) }
        end

        lc = Glossarist::LocalizedConcept.new
        lc.id = code
        lc.data = cdata
        lc
      end

      NOTE_RE = %r{<p>\s*Note\s+\d+\s+to\s+entry:.*?</p>}im
      EXAMPLE_RE = %r{<p>\s*Example\s*:\s*(?:</p>\s*<p>)?(.*?)</p>}im
      NOTE_TEXT_RE = /Note\s+\d+\s+to\s+entry:\s*/i

      def split_definition(html_text)
        notes = []
        examples = []

        html_text.scan(NOTE_RE) do
          note_html = Regexp.last_match[0]
          notes << strip_html(note_html).sub(NOTE_TEXT_RE, "").strip
        end

        definition_text = html_text
          .gsub(NOTE_RE, "")
          .gsub(EXAMPLE_RE) { examples << strip_html(Regexp.last_match[1]).strip; "" }
          .strip
        definition_text = nil if definition_text&.empty?

        { definition: definition_text, notes: notes, examples: examples }
      end

      def strip_html(html)
        return "" unless html
        html
          .gsub(/<li>/, "\n- ")
          .gsub(/<\/li>/, "")
          .gsub(/<ul>|<\/ul>|<ol>|<\/ol>/, "\n")
          .gsub(/<p>/, "\n")
          .gsub(/<\/p>/, "")
          .gsub(/<i>|<\/i>|<b>|<\/b>|<em>|<\/em>/, "")
          .gsub(/<br\s*\/?>/, "\n")
          .gsub(/<[^>]+>/, "")
          .gsub(/&amp;/, "&").gsub(/&lt;/, "<").gsub(/&gt;/, ">")
          .gsub(/&quot;/, "\"").gsub(/&#39;/, "'")
          .gsub(/\n{3,}/, "\n\n")
          .strip
      end
    end
  end
end
