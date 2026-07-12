# frozen_string_literal: true

module Iev
  module Reconciler
    # Extracts grammatical markers, context qualifiers, and part-of-speech
    # tags that are inline in Electropedia's live HTML term text, matching
    # how the termbase stores them in separate fields.
    #
    # Markers handled:
    #   Gender:      , f  , m  , n  (also multiple: , f, n)
    #                , ж  , м  , с  (Serbian Cyrillic)
    #   Number:      јд  , мн  (Serbian, after gender: , ж јд)
    #   Usage info:  <text> or , <text> → usage_info field
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
        "noun" => :isNoun,
        "명사" => :isNoun, "名詞" => :isNoun,
        "verb" => :isVerb,
        "동사" => :isVerb, "動詞" => :isVerb,
        "adj" => :isAdjective, "adjective" => :isAdjective,
        "형용사" => :isAdjective, "形容詞" => :isAdjective,
        "adjektiv" => :isAdjective,
        "adv" => :isAdverb, "adverb" => :isAdverb,
        "부사" => :isAdverb, "副詞" => :isAdverb,
      }.freeze

      SERBIAN_RE = /,\s*([жмс])\s+(јд|мн)\s*\z/
      WESTERN_RE = /,\s*([fmn])\s*\z/
      POS_RE = /,\s*(#{PART_OF_SPEECH_MAP.keys.map { |k| Regexp.escape(k) }.join("|")})\s*\z/i
      USAGE_INFO_RE = /[,\s]*<([^>]+)>\s*\z/

      Result = Struct.new(:designation, :genders, :numbers, :usage_info,
                          :part_of_speech_flags, keyword_init: true) do
        def gender_list
          genders || []
        end

        def number_list
          numbers || []
        end

        def pos_list
          part_of_speech_flags || []
        end
      end

      class << self
        def parse(term)
          return Result.new(designation: nil) unless term

          cleaned = term.strip.gsub(/\s+/, " ")
          designation = cleaned
          genders = []
          numbers = []
          usage_info = nil
          pos_flags = []

          loop do
            break if designation.nil? || designation.empty?

            if (m = designation.match(SERBIAN_RE))
              designation = designation[0, m.begin(0)].strip
              genders << GENDER_MAP[m[1]] if GENDER_MAP[m[1]]
              numbers << NUMBER_MAP[m[2]] if NUMBER_MAP[m[2]]
            elsif (m = designation.match(USAGE_INFO_RE))
              designation = designation[0, m.begin(0)].strip
              usage_info = m[1].strip
            elsif (m = designation.match(POS_RE))
              designation = designation[0, m.begin(0)].strip
              pos_key = m[1].downcase
              pos_flags << PART_OF_SPEECH_MAP[pos_key] if PART_OF_SPEECH_MAP[pos_key]
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
            usage_info: usage_info,
            part_of_speech_flags: pos_flags.uniq,
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
      end
    end
  end
end
