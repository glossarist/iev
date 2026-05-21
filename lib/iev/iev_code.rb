# frozen_string_literal: true

module Iev
  # Immutable value object that decomposes an IEV concept code
  # into its structural parts: area code, section code, and number.
  #
  # The IEV code format is AAA-BB-CC where:
  #   AAA = area code (e.g. "103")
  #   BB  = section sub-code (e.g. "01")
  #   CC  = concept number (e.g. "02")
  #
  # @example Full concept code
  #   code = Iev::IevCode.new("103-01-02")
  #   code.area_code    #=> "103"
  #   code.section_code #=> "103-01"
  #   code.number       #=> "02"
  #   code.area_uri     #=> "area-103"
  #   code.section_uri  #=> "section-103-01"
  #
  # @example Section code (no concept number)
  #   code = Iev::IevCode.new("103-01")
  #   code.area_code    #=> "103"
  #   code.section_code #=> "103-01"
  #   code.number       #=> nil
  #   code.section_uri  #=> "section-103-01"
  #
  class IevCode
    include Comparable

    attr_reader :raw, :area_code, :section_code, :number

    # @param code [#to_s] IEV reference, e.g. "103-01-02"
    def initialize(code)
      @raw = code.to_s
      parts = @raw.split("-")
      @area_code = parts[0]
      @section_code = parts.length >= 2 ? "#{parts[0]}-#{parts[1]}" : nil
      @number = parts.length >= 3 ? parts[2] : nil
      freeze
    end

    def area_uri
      "area-#{area_code}"
    end

    def section_uri
      "section-#{section_code}" if section_code
    end

    def to_s
      @raw
    end

    def to_str
      @raw
    end

    def ==(other)
      other.is_a?(self.class) && raw == other.raw
    end
    alias_method :eql?, :==

    def hash
      raw.hash
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    # Safe constructor that returns nil for codes that don't parse.
    # @param code [#to_s]
    # @return [IevCode, nil]
    def self.parse(code)
      new(code)
    rescue ArgumentError
      nil
    end
  end
end
