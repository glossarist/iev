# frozen_string_literal: true

module Iev
  module Converter
    def self.mathml_to_asciimath(input)
      Iev::Converter::MathmlToAsciimath.convert(input)
    end
  end
end
