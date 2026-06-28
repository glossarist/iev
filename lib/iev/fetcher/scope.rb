# frozen_string_literal: true

module Iev
  module Fetcher
    # Value object that captures which IEV sections a mirror/parse run
    # applies to. Decouples PageStore#each_concept from SubjectAreas.
    class Scope
      # @param sections [Array<Iev::Section>]
      def initialize(sections:)
        @sections = sections
      end

      # @return [Array<Iev::Section>]
      attr_reader :sections

      # Every section from every subject area.
      # @return [Scope]
      def self.all
        new(sections: SubjectAreas.all.flat_map(&:sections))
      end

      # All sections present in a CDX index. Use this when --cdx is the
      # authoritative source (yaml refresh is WAF-blocked, so SubjectAreas
      # is missing ~158 newer sections that archive.org has snapshots for).
      # Section titles and area_codes are synthesized from the code since
      # CDX only carries URLs.
      # @param cdx [Iev::Fetcher::CdxIndex]
      # @return [Scope]
      def self.from_cdx(cdx)
        sections = cdx.sections.map do |code|
          area_code = code.split("-").first.to_s
          Section.new(code: code, title: "", area_code: area_code)
        end
        new(sections: sections)
      end

      # All sections within one subject area.
      # @param code [String, Integer] e.g. "103"
      # @return [Scope]
      def self.for_area(code)
        new(sections: SubjectAreas.sections_for(code))
      end

      # A single section.
      # @param code [String] e.g. "103-01"
      # @return [Scope]
      # @raise [ArgumentError] if the section code is unknown.
      def self.for_section(code)
        section = SubjectAreas.find_section(code)
        raise ArgumentError, "Unknown section: #{code}" unless section

        new(sections: [section])
      end

      # True iff +code+'s parent section is in this scope.
      # @param code [String] e.g. "103-01-02"
      def includes?(code)
        section_code = IevCode.new(code.to_s).section_code
        return false unless section_code

        @sections.any? { |s| s.code == section_code }
      end

      def each_section(&)
        @sections.each(&)
      end

      def size = @sections.size
    end
  end
end
