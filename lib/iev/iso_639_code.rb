# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module IEV
  # @todo This needs to be rewritten.
  class Iso639Code
    COUNTRY_CODES = YAML.load(IO.read(File.join(__dir__, "iso_639_2.yaml")))
    THREE_CHAR_MEMO = {}

    def initialize(two_char_code)
      @code = case two_char_code.length
      when 2
        two_char_code
      else
        # This is to handle code "nl BE" in the IEV sheet
        two_char_code.split(" ").first
      end
    end

    def find(code_type)
      code = country_codes.detect do |key, value|
        key if value["iso_639_1"] == @code.to_s && value[code_type]
      end

      if code.nil?
        raise StandardError.new("Iso639Code not found for '#{@code}'!")
      end

      code
    end

    def self.three_char_code(two_char_code, code_type = "terminology")
      memo_index = [two_char_code, code_type]
      THREE_CHAR_MEMO[memo_index] ||= new(two_char_code).find(code_type)
    end

    private

    def country_codes
      COUNTRY_CODES
    end

  end
end

