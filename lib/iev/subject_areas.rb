# frozen_string_literal: true

require "yaml"
require "nokogiri"
require "fileutils"
require "iev/config"

module Iev
  module SubjectAreas
    DATA_FILE = File.expand_path("../../data/subject_areas.yaml", __dir__)

    AREAS_URL = "https://electropedia.org/iev/iev.nsf/" \
                "6d6bdd8667c378f7c12581fa003d80e7?OpenForm"
    SECTIONS_URL_TEMPLATE = "https://electropedia.org/iev/iev.nsf/" \
                            "index?openform&part=%<part>s"

    MIN_PAGE_SIZE = 15_000

    FETCH_DELAY = 5
    RETRY_DELAY = 30
    MAX_RETRIES = 2

    class FetchError < StandardError; end

    class << self
      # --- URI scheme ---

      # URI for a subject area concept.
      # @param code [String, Integer] e.g. "102"
      # @return [String] e.g. "area-102"
      def area_uri(code)
        "area-#{code}"
      end

      # URI for a section concept.
      # @param code [String] e.g. "103-01"
      # @return [String] e.g. "section-103-01"
      def section_uri(code)
        "section-#{code}"
      end

      # --- Query API (reads from bundled data) ---

      # Return all subject areas with their sections.
      # @return [Array<Hash>] each hash has "code", "title", "sections"
      def all
        data["areas"]
      end

      # Find a single subject area by its numeric code.
      # @param code [String, Integer] e.g. "102" or 102
      # @return [Hash, nil]
      def find_area(code)
        all.find { |a| a["code"] == code.to_s }
      end

      # Return all sections for a given area code.
      # @param code [String, Integer] area code, e.g. "102"
      # @return [Array<Hash>] each hash has "code", "title"
      def sections_for(code)
        area = find_area(code)
        area ? area["sections"] : []
      end

      # Find a single section by its section code.
      # @param section_code [String] e.g. "102-01"
      # @return [Hash, nil]
      def find_section(section_code)
        sc = section_code.to_s
        all.each do |area|
          found = area["sections"]&.find { |s| s["code"] == sc }
          return found if found
        end
        nil
      end

      # Return the parent area for a given section code.
      # @param section_code [String] e.g. "102-01"
      # @return [Hash, nil]
      def area_for_section(section_code)
        sc = section_code.to_s
        all.find do |area|
          area["sections"]&.any? { |s| s["code"] == sc }
        end
      end

      # --- Fetching (network, writes to bundled data file) ---

      def fetch
        cached = read_cache("subject_areas.yaml")
        return cached if cached && complete?(cached)

        areas = cached ? cached["areas"] : []
        fresh_areas = fetch_areas
        puts "Found #{fresh_areas.length} areas (#{areas.length} cached)" if $stdout.tty?

        # Merge: keep existing sections, add new areas
        existing = areas.each_with_object({}) { |a, h| h[a["code"]] = a }
        fresh_areas.each do |fa|
          existing[fa["code"]] ||= fa
        end
        areas = fresh_areas.map { |fa| existing[fa["code"]] || fa }

        areas.each_with_index do |area, i|
          next if area["fetched"]

          begin
            area["sections"] = fetch_sections(area["code"])
            area["fetched"] = true
          rescue FetchError
            area["sections"] ||= []
            warn "IEV: Skipping area #{area["code"]} due to WAF"
          end

          puts "[#{i + 1}/#{areas.length}] #{area["code"]}: #{area["title"]} — #{area["sections"].length} sections" if $stdout.tty?

          # Save progress every 10 areas so partial results survive WAF failures
          if (i + 1) % 10 == 0
            write_cache("subject_areas.yaml", { "areas" => areas })
          end

          sleep FETCH_DELAY unless i == areas.length - 1
        end

        result = { "areas" => areas }
        write_cache("subject_areas.yaml", result)
        result
      end

      def fetch_areas
        html = fetch_page_with_retry(AREAS_URL)
        doc = Nokogiri::HTML(html)

        areas = []
        doc.css("a").each do |link|
          href = link["href"].to_s
          next unless href.include?("part=")

          code = href.match(/part=(\d+)/)&.[](1)
          next unless code

          title = link.text.strip
          next if title.empty?

          areas << { "code" => code, "title" => title, "sections" => [] }
        end

        areas.uniq { |a| a["code"] }
      end

      def fetch_sections(part)
        url = format(SECTIONS_URL_TEMPLATE, part: part)
        html = fetch_page_with_retry(url)
        doc = Nokogiri::HTML(html)

        sections = []
        doc.css("td").each do |td|
          text = td.text.strip
          if (m = text.match(/\ASection\s+([\d-]+):\s*(.+)\z/))
            sections << { "code" => m[1], "title" => m[2].strip }
          end
        end

        sections.uniq { |s| s["code"] }
      end

      private

      def data
        @data ||= begin
          path = File.exist?(DATA_FILE) ? DATA_FILE : nil
          if path
            YAML.safe_load(File.read(path, encoding: "utf-8")) || { "areas" => [] }
          else
            { "areas" => [] }
          end
        end
      end

      def complete?(data)
        areas = data["areas"]
        return false unless areas&.length&.>= 99

        areas.all? { |a| a["fetched"] == true }
      end

      def captcha_page?(html)
        html.length < MIN_PAGE_SIZE ||
          html.include?("Confirm you are human") ||
          html.include?("solve a puzzle") ||
          html.include?("security check before continuing")
      end

      def fetch_page_with_retry(url, retries: MAX_RETRIES)
        require "iev/scraper/browser"

        retries.times do |attempt|
          html = ScraperBrowser.fetch(url)
          raise FetchError, "Failed to fetch #{url}" unless html

          unless captcha_page?(html)
            return html
          end

          if attempt < retries - 1
            wait = RETRY_DELAY * (attempt + 1)
            warn "IEV: WAF challenge for #{url}, retrying in #{wait}s (attempt #{attempt + 1}/#{retries})"
            sleep wait
          else
            raise FetchError, "WAF challenge for #{url}"
          end
        end
      end

      def read_cache(filename)
        cache_path = File.join(Iev.config.cache_dir, filename)
        return nil unless File.exist?(cache_path)

        d = YAML.safe_load(File.read(cache_path, encoding: "utf-8"))
        return nil unless d&.dig("areas")&.any?

        d
      end

      def write_cache(filename, d)
        cache_path = File.join(Iev.config.cache_dir, filename)
        FileUtils.mkdir_p(File.dirname(cache_path))
        File.write(cache_path, YAML.dump(d), encoding: "utf-8")
      end
    end
  end
end
