# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "English"
module Iev
  # Parses information from the spreadsheet's TERMATTRIBUTE column and alike.
  #
  # @example
  #   parser = TermAttrsParser.new(cell_data_string)
  #   parser.gender # returns grammatical gender
  #   parser.plurality # returns grammatical plurality
  #   parser.part_of_speech # returns part of speech
  class TermAttrsParser
    using DataConversions

    attr_reader :raw_str, :src_str, :gender, :geographical_area,
                :part_of_speech, :plurality, :prefix, :usage_info

    PARTS_OF_SPEECH = {
      "adj" => "adj",
      "noun" => "noun",
      "verb" => "verb",
      "名詞" => "noun",
      "動詞" => "verb",
      "形容詞" => "adj",
      "형용사" => "adj",
      "Adjektiv" => "adj",
      # Words seen in the iev-data #33 corpus (de, es, fr, it, pt, ar, ja, ko,
      # sr, zh); the value is a Glossarist grammar_info part_of_speech.
      "adjektivisch" => "adj",
      "adjectivo" => "adj",
      "agg" => "adj",
      "придев" => "adj",
      "صفة" => "adj",
      "形容词" => "adj",
      "Verb" => "verb",
      "verbe" => "verb",
      "verbo" => "verb",
      "глагол" => "verb",
      "فعل" => "verb",
      "动词" => "verb",
      "동사" => "verb",
      "名词" => "noun",
      "명사" => "noun",
      "إسم" => "noun",
      "substantif" => "noun",
      "adv" => "adverb",
      "прилог" => "adverb",
    }.freeze

    # Serbian (Cyrillic) gender letters: masculine, feminine, neuter.
    CYRILLIC_GENDERS = { "м" => "m", "ж" => "f", "с" => "n" }.freeze

    NUMBERS = {
      "pl" => "plural",
      "мн" => "plural",
      "복수" => "plural",
      "sg" => "singular",
      "јд" => "singular",
    }.freeze

    PREFIX_KEYWORDS = %w[
      Präfix prefix préfixe 接尾語 접두사 przedrostek prefixo 词头 префикс
    ].freeze

    # Markup that may legitimately appear inside <...> in a term.
    MARKUP_TAG = %r{
      \A/?(?:sub|sup|i|b|em|strong|span|small|a|p|r|br|simg|img|math|
      [\w-]+:\w+)(?:[\s/]|\z)
    }xi

    TERM_USAGE_INFO = /
      \s*<(?<inner>[^<>]+)>\s*
      |
      \s*\uFF1C(?<inner>[^\uFF1C\uFF1E]+)\uFF1E\s*
    /x

    # IEV terms carry usage info as a bare <text>, e.g. "badanie typu
    # <ogniw paliwowych>" (iev-data #128). Returns [term_without_it,
    # usage_info]; markup tags are left in place for later HTML conversion.
    def self.split_usage_info(raw_term)
      info = nil
      cleaned = raw_term.to_s.gsub(TERM_USAGE_INFO) do |match|
        inner = Regexp.last_match[:inner].strip
        next match if inner.empty? || inner.match?(MARKUP_TAG) ||
          inner.include?("=")

        info ||= inner
        " "
      end

      info ? [cleaned.strip, info] : [raw_term, nil]
    end

    def initialize(attr_str)
      @raw_str = attr_str.dup.freeze
      @src_str = decode_attrs_string(raw_str).freeze
      parse
    end

    def inspect
      "<ATTRIBUTES: #{src_str}>".freeze
    end

    # Constructs a Glossarist::Designation::GrammarInfo from the parsed
    # gender, plurality, and part_of_speech attributes.
    # Returns nil if none of these attributes were parsed.
    def to_grammar_info
      return nil unless gender || plurality || part_of_speech

      Glossarist::Designation::GrammarInfo.new(
        gender: gender ? [gender] : nil,
        number: plurality ? [plurality] : nil,
        part_of_speech: part_of_speech,
      )
    end

    private

    def parse
      curr_str = src_str.dup

      # Usage info goes first: its free text may contain single letters
      # such as "n" that would otherwise be read as a gender.
      extract_usage_info(curr_str)
      extract_gender(curr_str)
      extract_plurality(curr_str)
      extract_geographical_area(curr_str)
      extract_part_of_speech(curr_str)
      extract_prefix(curr_str)

      nil unless /\p{Word}/.match?(curr_str)

      # Term attributes could not be parsed completely
    end

    def extract_gender(str)
      # Match gender either:
      # 1. Inside brackets/parentheses: (m), [f], (n)
      # 2. As standalone word with boundaries: m, f, n
      gender_rx = /(?:\(|\[)[mfnмжс](?:\)|\])|\b[mfnмжс]\b/

      match = remove_from_string(str, gender_rx)
      # Extract just the letter from the match (remove brackets if present)
      letter = match&.gsub(/[\[\]()]/, "")
      @gender = CYRILLIC_GENDERS.fetch(letter, letter)
    end

    # Must happen after #extract_gender
    def extract_plurality(str)
      # Match a number marker either inside brackets/parentheses or as a
      # standalone word with boundaries: pl, sg, мн, јд, 복수
      keys = Regexp.union(NUMBERS.keys)
      number_rx = /(?:\(|\[)#{keys}(?:\)|\])|\b#{keys}\b/

      removed = remove_from_string(str, number_rx)
      if removed
        @plurality = NUMBERS[removed.gsub(/[\[\]()]/, "")]
      elsif !gender.nil?
        # TODO: Really needed?
        @plurality = "singular"
      end
    end

    # TODO: this is likely buggy
    def extract_geographical_area(str)
      ga_rx = /\b[A-Z]{2}$/

      @geographical_area = remove_from_string(str, ga_rx)
    end

    def extract_part_of_speech(str)
      pos_rx = /
        \b
        #{Regexp.union(PARTS_OF_SPEECH.keys)}
        \b
      /x

      removed = remove_from_string(str, pos_rx)
      @part_of_speech = PARTS_OF_SPEECH[removed] || removed
    end

    def extract_usage_info(str)
      info_rx = /
        # regular ASCII less and greater than signs
        < (?<inner>.*?) >
        |
        # ＜ and ＞, i.e. full-width less and greater than signs
        # which are used instead of ASCII signs in some CJK terms
        \uFF1C (?<inner>.*?) \uFF1E
      /x

      remove_from_string(str, info_rx) do |md|
        @usage_info = md[:inner].strip
      end
    end

    def extract_prefix(str)
      prefix_rx = /
        \b
        #{Regexp.union(PREFIX_KEYWORDS)}
        \b
      /x

      removed = remove_from_string(str, prefix_rx)
      @prefix = removed if removed
    end

    def decode_attrs_string(str)
      decoded = str.decode_html || ""
      # Strip common HTML inline tags that appear in TERMATTRIBUTE data
      # and would interfere with usage_info angle-bracket parsing.
      # Only strip known HTML tags, not usage_info like <telecommunications>.
      decoded.gsub(/<\/?(?:sup|sub|i|b|em|strong|span|small)>/, "")
    end

    def remove_from_string(string, regexp)
      string.sub!(regexp, "")

      if $LAST_MATCH_INFO && block_given?
        yield $LAST_MATCH_INFO
      else
        ::Regexp.last_match(0) # removed substring or nil
      end
    end
  end
end
