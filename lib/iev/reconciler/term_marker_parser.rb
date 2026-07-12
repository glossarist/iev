# frozen_string_literal: true

module Iev
  module Reconciler
    # Extracts grammatical markers, context qualifiers, and part-of-speech
    # tags that are inline in Electropedia's live HTML term text, matching
    # how the termbase stores them in separate fields.
    #
    # Two-pass approach:
    #   Pass 1: extract context qualifiers in angle brackets (<text>) → usage_info
    #   Pass 2: extract gender/number/POS markers from remaining text
    #
    # Markers handled:
    #   Gender:      , f  , m  , n  (also multiple: , f, n)
    #                , ж  , м  , с  (Serbian Cyrillic)
    #   Number:      јд  , мн  (Serbian, after gender: , ж јд)
    #   Usage info:  <text> → usage_info field
    #   Part of speech: , 名詞 , 명사 , noun , verb , adj , etc.
    class TermMarkerParser
      GENDER_MAP = {
        "f" => "feminine", "m" => "masculine", "n" => "neuter",
        "ж" => "feminine", "м" => "masculine", "с" => "neuter",
      }.freeze

      NUMBER_MAP = {
        "јд" => "singular", "мн" => "plural",
      }.freeze

      PART_OF_SPEECH_MAP = {
        "noun" => "noun",
        "명사" => "noun", "名詞" => "noun",
        "именица" => "noun",
        "verb" => "verb",
        "동사" => "verb", "動詞" => "verb",
        "глагол" => "verb",
        "adj" => "adj", "adjective" => "adj",
        "형용사" => "adj", "形容詞" => "adj",
        "adjektiv" => "adj",
        "придев" => "adj",
        "adv" => "adv", "adverb" => "adv",
        "부사" => "adv", "副詞" => "adv",
        "прилог" => "adv",
      }.freeze

      USAGE_INFO_RE = /<([^>]+)>/
      SERBIAN_RE = /,\s*([жмс])\s+(јд|мн)\s*\z/
      WESTERN_RE = /,\s*([fmn])\s*\z/
      POS_RE = /,\s*(#{PART_OF_SPEECH_MAP.keys.map { |k| Regexp.escape(k) }.join("|")})\s*\z/i
      TRAILING_PUNCT_RE = /[,;\s]+$/

      IEV_XREF_RE = /<[^>]*IEV\s*(\d{3}-\d{2}-\d{2,3})[^>]*>/i

      Result = Struct.new(:designation, :genders, :numbers, :usage_info,
                          :part_of_speech, :related_refs, keyword_init: true)

      class << self
        def parse(term)
          return Result.new(designation: nil) unless term

          text = decode_entities(term).strip.gsub(/\s+/, " ")
          related_refs, text = extract_iev_xrefs(text)
          usage_info, text = extract_usage_info(text)
          designation, genders, numbers, pos = extract_markers(text)

          Result.new(
            designation: designation,
            genders: genders,
            numbers: numbers,
            usage_info: usage_info,
            part_of_speech: pos,
            related_refs: related_refs,
          )
        end

        def parse_multiple(term_text)
          return [] unless term_text

          term_text
            .split(/\n+/)
            .map(&:strip)
            .reject(&:empty?)
            .map { |part| parse(part) }
        end

        private

        def decode_entities(str)
          str
            .gsub(/&lt;/, "<")
            .gsub(/&gt;/, ">")
            .gsub(/&amp;/, "&")
            .gsub(/&quot;/, '"')
            .gsub(/&#39;/, "'")
        end

        def extract_usage_info(text)
          match = text.match(USAGE_INFO_RE)
          return [nil, text] unless match

          usage = match[1].strip
          remaining = text.sub(match[0], "").gsub(TRAILING_PUNCT_RE, "").strip
          remaining = remaining.sub(/^[,;\s]+/, "").strip
          [usage, remaining]
        end

        def extract_iev_xrefs(text)
          refs = []
          remaining = text
          while (match = remaining.match(IEV_XREF_RE))
            refs << match[1]
            remaining = remaining.sub(match[0], "").gsub(TRAILING_PUNCT_RE, "").strip
            remaining = remaining.sub(/^[,;\s]+/, "").strip
          end
          [refs.empty? ? nil : refs, remaining]
        end

        def extract_markers(text)
          designation = text
          genders = []
          numbers = []
          pos = nil

          loop do
            break if designation.nil? || designation.empty?

            if (m = designation.match(SERBIAN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
              numbers << NUMBER_MAP[m[2]] if NUMBER_MAP[m[2]]
            elsif (m = designation.match(POS_RE))
              designation = designation[0, m.begin(0)].strip
              pos = PART_OF_SPEECH_MAP[m[1].downcase]
            elsif (m = designation.match(WESTERN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
            else
              break
            end
          end

          [designation, genders.uniq, numbers.uniq, pos]
        end
      end
    end
  end
end
