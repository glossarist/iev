# frozen_string_literal: true

module Iev
  module Reconciler
    # Extracts grammatical gender and plurality markers that are inline
    # in Electropedia's live HTML term text and separates them from the
    # designation. Supports multiple markers (e.g. German "LED-Package, f, n"
    # means the word can be feminine OR neuter).
    #
    # Maps short marker codes to concept-model GrammarGender/GrammarNumber
    # enum values:
    #   f → feminine, m → masculine, n → neuter
    #   ж → feminine, м → masculine, с → neuter (Serbian Cyrillic)
    #   јд → singular, мн → plural (Serbian Cyrillic)
    #
    # Also splits multi-designation cells (terms separated by newlines from
    # <br> tags) into separate entries via parse_multiple.
    class TermMarkerParser
      GENDER_MAP = {
        "f" => "feminine", "m" => "masculine", "n" => "neuter",
        "ж" => "feminine", "м" => "masculine", "с" => "neuter",
      }.freeze

      NUMBER_MAP = {
        "јд" => "singular", "мн" => "plural",
      }.freeze

      # Serbian pattern: ", ж јд" or ", м мн" — gender + number separated by space
      SERBIAN_RE = /,\s*([жмс])\s+(јд|мн)\s*\z/

      # Western pattern: ", f" or ", f, n" — comma-separated single-char markers
      WESTERN_RE = /,\s*([fmn])\s*\z/

      Result = Struct.new(:designation, :genders, :numbers, keyword_init: true) do
        def gender_list
          genders || []
        end

        def number_list
          numbers || []
        end
      end

      class << self
        # @param term [String, nil] raw term text from enriched HTML
        # @return [Result] designation + parsed grammar info
        def parse(term)
          return Result.new(designation: nil) unless term

          cleaned = term.strip.gsub(/\s+/, " ")
          designation = cleaned
          genders = []
          numbers = []

          loop do
            break if designation.nil? || designation.empty?

            if (m = designation.match(SERBIAN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
              numbers << NUMBER_MAP[m[2]] if NUMBER_MAP[m[2]]
            elsif (m = designation.match(WESTERN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
            else
              break
            end
          end

          Result.new(
            designation: designation,
            genders: genders.uniq,
            numbers: numbers.uniq,
          )
        end

        # Split a multi-designation cell (terms separated by newlines from
        # <br> tags) into individual terms, then parse markers for each.
        # @param term_text [String, nil]
        # @return [Array<Result>] one Result per designation
        def parse_multiple(term_text)
          return [] unless term_text

          term_text
            .split(/\n+/)
            .map(&:strip)
            .reject(&:empty?)
            .map { |part| parse(part) }
        end
      end
    end
  end
end
