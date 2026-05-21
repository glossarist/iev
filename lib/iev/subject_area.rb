# frozen_string_literal: true

module Iev
  # Immutable value object representing an IEV subject area (e.g. "102").
  #
  # A subject area is the aggregate root for its sections.
  # Navigation: area → sections (direct), section → area (via registry).
  class SubjectArea
    attr_reader :code, :title, :sections

    # @param code [#to_s] area code, e.g. "103"
    # @param title [#to_s] area title, e.g. "Mathematics - Functions"
    # @param sections [Array<Iev::Section>] child sections
    def initialize(code:, title:, sections: [])
      @code = code.to_s
      @title = title.to_s
      @sections = sections
      freeze
    end

    def uri
      "area-#{code}"
    end

    def section(section_code)
      sections.find { |s| s.code == section_code.to_s }
    end

    def to_h
      {
        "code" => code,
        "title" => title,
        "sections" => sections.map(&:to_h),
      }
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
