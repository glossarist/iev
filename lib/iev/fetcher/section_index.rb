# frozen_string_literal: true

require "nokogiri"

module Iev
  module Fetcher
    # Fetches a per-section Electropedia browse page and extracts the
    # concept codes listed on it. The fetcher collaborator is injectable so
    # specs can drive SectionIndex without a network.
    class SectionIndex
      SECTION_INDEX_URL = "https://www.electropedia.org/iev/iev.nsf/" \
                          "index?openform&part=%<section>s"
      CONCEPT_CODE_RE = /\b(\d{3}-\d{2}-\d{2})\b/

      # @param section_code [String, Iev::Section] e.g. "103-01"
      # @param fetcher [Module] anything that responds to +.fetch(url)+
      #   and returns HTML or nil. Defaults to +Iev::Scraper::Browser+.
      def initialize(section_code, fetcher: Iev::Scraper::Browser)
        @section_code = section_code.to_s
        @fetcher = fetcher
      end

      # Fetch the browse page and return the concept codes it lists.
      # @return [Array<String>] sorted unique concept codes; empty on failure.
      def concept_codes
        concept_codes_from(fetch_html)
      end

      # Pure parser; public so callers can reuse it on already-cached HTML.
      # @param html [String, nil]
      # @return [Array<String>] sorted unique concept codes; empty if html
      #   is nil.
      def concept_codes_from(html)
        return [] unless html

        Nokogiri::HTML(html).css("a")
          .filter_map { |a| a["href"].to_s[CONCEPT_CODE_RE, 1] }
          .uniq.sort
      end

      private

      def fetch_html
        Waf.fetch_with_retry do
          @fetcher.fetch(format(SECTION_INDEX_URL, section: @section_code))
        end
      rescue Waf::Error => e
        warn "IEV: Skipping section #{@section_code}: #{e.message}"
        nil
      end
    end
  end
end
