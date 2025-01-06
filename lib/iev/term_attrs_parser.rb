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
    include Cli::Ui
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
    }.freeze

    PREFIX_KEYWORDS = %w[
      Präfix prefix préfixe 接尾語 접두사 przedrostek prefixo 词头
    ].freeze

    def initialize(attr_str)
      @raw_str = attr_str.dup.freeze
      @src_str = decode_attrs_string(raw_str).freeze
      parse
    end

    def inspect
      "<ATTRIBUTES: #{src_str}>".freeze
    end

    private

    def parse
      curr_str = src_str.dup

      extract_gender(curr_str)
      extract_plurality(curr_str)
      extract_geographical_area(curr_str)
      extract_part_of_speech(curr_str)
      extract_usage_info(curr_str)
      extract_prefix(curr_str)

      return unless /\p{Word}/.match?(curr_str)

      debug(
        :term_attributes,
        "Term attributes could not be parsed completely: '#{src_str}'",
      )
    end

    def extract_gender(str)
      gender_rx = /\b[mfn]\b/

      @gender = remove_from_string(str, gender_rx)
    end

    # Must happen after #extract_gender
    def extract_plurality(str)
      plural_rx = /\bpl\b/

      if remove_from_string(str, plural_rx)
        @plurality = "plural"
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

      @prefix = true if remove_from_string(str, prefix_rx)
    end

    def decode_attrs_string(str)
      str.decode_html || ""
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
