# frozen_string_literal: true

require "net/http"
require "uri"
require "yaml"

module Iev
  module DataSource
    class NotFoundError < StandardError; end

    class << self
      # Fetch full concept data (all languages) for a given IEV code.
      #
      # @param code [String] IEV code, e.g. "103-01-02"
      # @return [Hash] concept data hash
      # @raise [NotFoundError] if the concept does not exist
      def fetch_concept(code)
        fetch_concept_data(code) ||
          raise(NotFoundError, "IEV concept not found: #{code}")
      end

      # Fetch localized term data for a given IEV code and language.
      #
      # @param code [String] IEV code, e.g. "103-01-02"
      # @param lang [String] language code, e.g. "en" or "eng"
      # @return [Hash, nil] localized concept data or nil if language not found
      # @raise [NotFoundError] if the concept does not exist
      def fetch_term(code, lang)
        concept = fetch_concept(code)

        lang_key = normalize_lang(lang)
        concept[lang_key]
      end

      # Fetch the term designation string for a given IEV code and language.
      # This is the backward-compatible replacement for the scraping-based Iev.get.
      #
      # @param code [String] IEV code, e.g. "103-01-02"
      # @param lang [String] language code, e.g. "en"
      # @return [String, nil] term designation or nil if not found
      # @raise [NotFoundError] if the concept does not exist
      def fetch_term_designation(code, lang)
        term_data = fetch_term(code, lang)
        return nil unless term_data

        terms = term_data["terms"]
        return nil unless terms&.any?

        preferred = terms.find { |t| t["normative_status"] == "preferred" }
        (preferred || terms.first)["designation"]
      end

      private

      def fetch_concept_data(code)
        from_local(code) || from_remote(code)
      end

      def from_local(code)
        data_path = Iev.config.data_path
        return nil unless data_path

        path = File.join(data_path, "concept-#{code}.yaml")
        return nil unless File.exist?(path)

        YAML.safe_load(File.read(path, encoding: "utf-8"),
                       permitted_classes: [Date, Time])
      end

      def from_remote(code)
        cache_key = "concept-#{code}.yaml"
        cached = read_cache(cache_key)
        return cached if cached

        url = "#{Iev.config.remote_base_url}/#{cache_key}"
        data = http_get_yaml(url)
        return nil unless data

        write_cache(cache_key, data)
        data
      end

      def http_get_yaml(url)
        uri = URI(url)
        response = Net::HTTP.get_response(uri)

        case response.code
        when "200"
          YAML.safe_load(response.body, permitted_classes: [Date, Time])
        when "404"
          nil
        else
          warn "IEV: Failed to fetch #{url}: HTTP #{response.code}"
          nil
        end
      rescue SocketError, Timeout::Error => e
        warn "IEV: Network error fetching #{url}: #{e.message}"
        nil
      end

      def read_cache(filename)
        cache_path = cache_file_path(filename)
        return nil unless File.exist?(cache_path)

        YAML.safe_load(File.read(cache_path, encoding: "utf-8"),
                       permitted_classes: [Date, Time])
      end

      def write_cache(filename, data)
        cache_path = cache_file_path(filename)
        FileUtils.mkdir_p(File.dirname(cache_path))
        File.write(cache_path, YAML.dump(data), encoding: "utf-8")
      end

      def cache_file_path(filename)
        File.join(Iev.config.cache_dir, filename)
      end

      # Normalize language code: "en" → "eng", "de" → "deu", etc.
      def normalize_lang(lang)
        return lang if lang.length == 3

        Iso639Code.three_char_code(lang).first
      rescue StandardError
        lang
      end
    end
  end
end
