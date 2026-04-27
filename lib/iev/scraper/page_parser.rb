# frozen_string_literal: true

module Iev
  class Scraper
    # Parses an Electropedia HTML page into a concept data hash.
    #
    # The Electropedia HTML structure is a table with rows for each language:
    # - Language row: <div align="center"><font color="#800080">en</font></div>
    # - Term cell: <b>term text</b> in the third <td>
    # - Definition row: next row's third <td> (if present)
    # - Empty/separator rows with <hr> or spacer images
    class PageParser
      # Map Electropedia HTML language codes to ISO 639-2/3 three-char codes.
      LANG_CODE_MAP = {
        "en" => "eng",
        "fr" => "fra",
        "ar" => "ara",
        "de" => "deu",
        "es" => "spa",
        "it" => "ita",
        "ko" => "kor",
        "ja" => "jpn",
        "pl" => "pol",
        "pt" => "por",
        "sr" => "srp",
        "sv" => "swe",
        "zh" => "zho",
        "nl" => "nld",
        "fi" => "fin",
        "cs" => "ces",
        "no" => "nor",
        "ru" => "rus",
        "sl" => "slv",
        "sk" => "slk",
      }.freeze

      def initialize(doc, code)
        @doc = doc
        @code = code
      end

      def parse
        return nil unless find_iev_ref

        {
          "id" => @code,
          "data" => {
            "identifier" => @code,
            "localized_concepts" => localized_concepts,
          },
        }
      end

      private

      def find_iev_ref
        # Find the IEV reference cell to confirm the page is valid
        @doc.at_css("b:contains('#{@code}')") ||
          @doc.at_xpath("//td/b[contains(text(), '#{@code}')]")
      end

      def localized_concepts
        result = {}
        lang_sections.each do |lang, term_row, def_row|
          term = extract_term(term_row)
          next unless term

          entry = { "term" => term }
          definition = extract_definition(def_row)
          entry["definition"] = definition if definition

          result[lang] = entry
        end
        result
      end

      # Finds all language sections in the table.
      # Returns array of [lang_code, term_row, definition_row] tuples.
      def lang_sections
        sections = []
        rows = content_rows

        rows.each_with_index do |row, idx|
          lang = extract_lang(row)
          next unless lang

          # The definition is in the next non-empty, non-separator row
          def_row = find_definition_row(rows, idx + 1)
          sections << [lang, row, def_row]
        end

        sections
      end

      def content_rows
        # Find the main content table (the one with language data)
        # It's the largest table with IEV data
        tables = @doc.css("table")
        content_table = tables.max_by { |t| t.css("tr").length }
        content_table ? content_table.css("tr").to_a : []
      end

      def extract_lang(row)
        font = row.at_css("div[align='center'] font[color='#800080']")
        return nil unless font

        lang_code = font.text.strip.downcase
        LANG_CODE_MAP[lang_code]
      end

      def extract_term(row)
        # Term is in the third <td> — may be in a <b> tag (en, fr) or plain text
        tds = row.css("td")
        return nil if tds.length < 3

        content_td = tds[2]
        bold = content_td.at_css("b")

        term = bold ? bold.text.strip : content_td.text.strip
        term.empty? ? nil : term
      end

      def extract_definition(row)
        return nil unless row

        tds = row.css("td")
        return nil if tds.length < 3

        content_td = tds[2]
        # The definition is the text content, which may include MathML
        html = content_td.inner_html.strip
        return nil if html.empty? || html.match?(/\A<img.*ecblank/)

        html
      end

      # Find the definition row following a language row.
      # Skip separator rows (empty, <hr>, or spacer images).
      def find_definition_row(rows, start_idx)
        return nil if start_idx >= rows.length

        row = rows[start_idx]
        return nil if extract_lang(row)
        return nil if separator?(row)

        tds = row.css("td")
        return nil if tds.length < 3

        content = tds[2].inner_html.strip
        return nil if content.empty?

        # Skip rows that are only spacer images (unless they have <b> content)
        if content.match?(/\A<img.*ecblank/) && !content.include?("<b>")
          return nil
        end

        row
      end

      def separator?(row)
        tds = row.css("td")
        return true if tds.any? { |td| td.at_css("hr") }

        tds.all? { |td| spacer_only?(td) }
      end

      def spacer_only?(cell)
        html = cell.inner_html.strip
        return true if html.empty?
        return true if html.match?(/\A<img.*ecblank/)

        cell.at_css("img[src*='ecblank']") && cell.text.strip.empty?
      end
    end
  end
end
