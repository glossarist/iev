# frozen_string_literal: true

module Iev
  module Reconciler
    # Extracts grammatical markers, context qualifiers, and part-of-speech
    # tags that are inline in Electropedia's live HTML term text, matching
    # how the termbase stores them in separate fields.
    #
    # Two-pass approach:
    #   Pass 1: extract context qualifiers and IEV cross-references from
    #           angle brackets (<text>, <相关条目：IEV xxx>)
    #   Pass 2: extract gender/number/POS/prefix markers from remaining text
    #
    # Marker formats handled:
    #   Gender:      , f  , m  , n  (also multiple: , f, n)
    #                , ж  , м  , с  (Serbian Cyrillic)
    #                , m/f  (slash = both apply)
    #   Number:      , pl , sg  (also Serbian: јд, мн)
    #                , f pl  (space-separated gender+number)
    #   Usage info:  <text> → usage_info field
    #   Part of speech: , 名詞 , 명사 , noun , verb , adj. , agg , etc.
    #   Prefix:      , Präfix , 접두사 , 接頭語 , etc. → prefix flag
    class TermMarkerParser
      GENDER_MAP = {
        "f" => "feminine", "m" => "masculine", "n" => "neuter",
        "ж" => "feminine", "м" => "masculine", "с" => "neuter",
      }.freeze

      NUMBER_MAP = {
        "јд" => "singular", "мн" => "plural",
        "sg" => "singular", "pl" => "plural",
      }.freeze

      PART_OF_SPEECH_MAP = {
        "noun" => "noun",
        "명사" => "noun", "名詞" => "noun", "اسم" => "noun",
        "именица" => "noun",
        "verb" => "verb", "verbo" => "verb",
        "동사" => "verb", "動詞" => "verb", "فعل" => "verb",
        "глагол" => "verb",
        "adj" => "adj", "adj." => "adj", "adjective" => "adj",
        "agg" => "adj", "agg." => "adj",
        "형용사" => "adj", "形容詞" => "adj", "صفة" => "adj",
        "adjektiv" => "adj", "придев" => "adj",
        "adv" => "adv", "adv." => "adv", "adverb" => "adv",
        "부사" => "adv", "副詞" => "adv",
        "прилог" => "adv",
      }.freeze

      PREFIX_KEYWORDS = %w[
        Präfix prefix préfixe 접두사 接頭語 接尾語
      ].freeze

      DOMAIN_RE = /<([^>]+)>/
      USAGE_INFO_RE = /\(([^)]+)\)\s*(?=[,]?\s*(?:[fmnжмс]\b|[fmn]\/[fmn]|sg|pl|јд|мн|\z))/i
      IEV_XREF_RE = /<[^>]*IEV\s*(\d{3}-\d{2}-\d{2,3})[^>]*>/i

      SERBIAN_RE = /,\s*([жмс])\s+(јд|мн)\s*\z/
      WESTERN_GENDER_NUMBER_RE = /,\s*([fmn])\s+(sg|pl)\.?\s*\z/i
      WESTERN_NUMBER_RE = /,\s*(sg|pl)\.?\s*\z/i
      SLASH_GENDER_RE = /,\s*([fmn])\/([fmn])\s*\z/i
      WESTERN_RE = /[,]?\s+([fmn])\s*\z/
      SPACE_GENDER_RE = /\s+([fmn])\s*\z/

      POS_RE = /,\s*(#{PART_OF_SPEECH_MAP.keys.map { |k| Regexp.escape(k) }.join("|")})\s*\z/i
      PREFIX_RE = /,\s*(#{PREFIX_KEYWORDS.map { |k| Regexp.escape(k) }.join("|")})\s*\z/

      TRAILING_PUNCT_RE = /[,;\s]+$/

      Result = Struct.new(:designation, :genders, :numbers, :domain,
                          :usage_info, :part_of_speech, :related_refs,
                          :is_prefix, keyword_init: true)

      class << self
        def parse(term)
          return Result.new(designation: nil) unless term

          text = decode_entities(term).strip.gsub(/\s+/, " ")
          related_refs, text = extract_iev_xrefs(text)
          domain, text = extract_domain(text)
          usage_info, text = extract_usage_info(text)
          designation, genders, numbers, pos, is_prefix = extract_markers(text)

          Result.new(
            designation: designation,
            genders: genders,
            numbers: numbers,
            domain: domain,
            usage_info: usage_info,
            part_of_speech: pos,
            related_refs: related_refs,
            is_prefix: is_prefix,
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

        # Extract domain qualifier from angle brackets: <text> -> domain
        def extract_domain(text)
          match = text.match(DOMAIN_RE)
          return [nil, text] unless match

          domain = match[1].strip
          remaining = text.sub(match[0], "").gsub(TRAILING_PUNCT_RE, "").strip
          remaining = remaining.sub(/^[,;\s]+/, "").strip
          [domain, remaining]
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

        # Extract usage_info from parentheses that precede trailing markers.
        # E.g. "Orientierung (einer Kurve) f" -> usage_info="einer Kurve"
        def extract_usage_info(text)
          match = text.match(USAGE_INFO_RE)
          return [nil, text] unless match

          usage = match[1].strip
          remaining = text.sub(match[0], "").gsub(/\s+/, " ").strip
          [usage, remaining]
        end

        def extract_markers(text)
          designation = text
          genders = []
          numbers = []
          pos = nil
          is_prefix = false

          loop do
            break if designation.nil? || designation.empty?

            if (m = designation.match(SERBIAN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
              numbers << NUMBER_MAP[m[2]] if NUMBER_MAP[m[2]]
            elsif (m = designation.match(SLASH_GENDER_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
              genders << GENDER_MAP[m[2]] if GENDER_MAP[m[2]]
            elsif (m = designation.match(WESTERN_GENDER_NUMBER_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
              num_key = m[2].downcase.sub(/\.$/, "")
              numbers << NUMBER_MAP[num_key] if NUMBER_MAP[num_key]
            elsif (m = designation.match(WESTERN_NUMBER_RE))
              designation = designation[0, m.begin(0)].strip
              num_key = m[1].downcase.sub(/\.$/, "")
              numbers << NUMBER_MAP[num_key] if NUMBER_MAP[num_key]
            elsif (m = designation.match(POS_RE))
              designation = designation[0, m.begin(0)].strip
              pos = PART_OF_SPEECH_MAP[m[1].downcase]
            elsif (m = designation.match(PREFIX_RE))
              designation = designation[0, m.begin(0)].strip
              is_prefix = true
            elsif (m = designation.match(WESTERN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
            else
              break
            end
          end

          [designation, genders.uniq, numbers.uniq, pos, is_prefix]
        end
      end
    end
  end
end
