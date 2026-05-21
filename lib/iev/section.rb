# frozen_string_literal: true

module Iev
  # Immutable value object representing an IEV section (e.g. "103-01").
  #
  # A section belongs to exactly one area, identified by +area_code+.
  class Section
    attr_reader :code, :title, :area_code

    # @param code [#to_s] section code, e.g. "103-01"
    # @param title [#to_s] section title, e.g. "General concepts on functions"
    # @param area_code [#to_s] parent area code, e.g. "103"
    def initialize(code:, title:, area_code:)
      @code = code.to_s
      @title = title.to_s
      @area_code = area_code.to_s
      freeze
    end

    def uri
      "section-#{code}"
    end

    def to_h
      { "code" => code, "title" => title }
    end

    def ==(other)
      other.is_a?(self.class) && code == other.code
    end
    alias_method :eql?, :==

    def hash
      code.hash
    end
  end
end
