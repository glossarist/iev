# frozen_string_literal: true

module IEV
  module Converter
    def self.mathml_to_asciimath(input)
      IEV::Converter::MathmlToAsciimath.convert(input)
    end
  end
end
