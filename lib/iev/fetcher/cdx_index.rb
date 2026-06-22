# frozen_string_literal: true

require "json"

module Iev
  module Fetcher
    # Indexes CDX snapshot data into a {section_code => [concept_code, ...]}
    # map so ArchiveProbe can iterate the exact set of codes that
    # archive.org has snapshots for, without probing every possible
    # <section>-NN and stopping on the first gap.
    #
    # CDX input format (from web.archive.org/cdx/search/cdx):
    #   [["original","timestamp"], [url1, ts1], [url2, ts2], ...]
    #
    # The original URL looks like:
    #   https://electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-18
    # We extract the ievref code and bucket by section (the first two
    # dash-separated components: "102-05" for "102-05-18").
    class CdxIndex
      CODE_RE = /ievref=(\d+-\d+-\d+)/

      # @param cdx_json_path [String, Pathname] path to a CDX JSON file.
      # @return [CdxIndex]
      def self.load(cdx_json_path)
        rows = JSON.parse(File.read(cdx_json_path, encoding: "utf-8"))
        new(rows[1..] || [])
      end

      # @param rows [Array<Array<String>>] CDX rows after the header.
      def initialize(rows)
        @rows = rows
      end

      # @return [Integer] total unique concept codes indexed.
      def total_codes
        by_section.values.sum(&:size)
      end

      # @param section_code [String] e.g. "102-05".
      # @return [Array<String>] sorted concept codes in this section.
      def codes_for_section(section_code)
        by_section[section_code.to_s].dup.sort
      end

      # @return [Array<String>] all unique section codes that have snapshots.
      def sections
        by_section.keys.sort
      end

      private

      def by_section
        @by_section ||= build_index
      end

      def build_index
        index = Hash.new { |h, k| h[k] = [] }
        @rows.each do |row|
          code = row.first[CODE_RE, 1] or next
          section = section_of(code)
          index[section] << code unless index[section].include?(code)
        end
        index
      end

      def section_of(code)
        code.split("-").take(2).join("-")
      end
    end
  end
end
