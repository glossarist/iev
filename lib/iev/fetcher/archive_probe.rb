# frozen_string_literal: true

module Iev
  module Fetcher
    # Iterates a known list of concept codes for one section, fetching
    # each from the injected source. Unlike SequentialProbe, a nil fetch
    # result is treated as "skip this code" rather than "section ended" —
    # the right semantics for Source::Archive, which has gaps in coverage.
    #
    # The code list typically comes from CdxIndex#codes_for_section, but
    # any Enumerable of IEV codes will do.
    class ArchiveProbe
      # @param store [PageStore, nil] for cache lookups.
      # @param refresh [Boolean] re-fetch even if cached.
      Options = Struct.new(:store, :refresh, keyword_init: true) do
        def initialize(store: nil, refresh: false)
          super
        end
      end

      # @param section_code [String] e.g. "103-01". Used for diagnostics only.
      # @param codes [Enumerable<String>] concept codes to probe.
      # @param fetcher [#fetch(url)] the source of HTML.
      # @param validator [#valid?(html, code)] distinguishes real pages from
      #   placeholders.
      # @param options [Options] cache + refresh tuning.
      def initialize(section_code, codes:, fetcher:, validator:,
                     options: Options.new)
        @section_code = section_code.to_s
        @codes = codes.to_a.sort
        @fetcher = fetcher
        @validator = validator
        @options = options
      end

      # Yields (code, html, status) per code in the list.
      # Status:
      #   - :ok          — fetched live and validated.
      #   - :skipped     — already cached; html is the cached body.
      #   - :waf_blocked — fetch hit an uncleared WAF challenge; html is nil.
      #
      # Codes with no snapshot (fetcher returned nil) are silently skipped
      # WITHOUT yielding — this is the core difference from SequentialProbe,
      # which would treat that as end-of-section.
      #
      # Stops iteration after yielding :waf_blocked (the rest of the
      # section's codes may exist but cannot be reached until WAF clears).
      def each_concept
        return enum_for(:each_concept) unless block_given?

        @codes.each do |code|
          outcome = outcome_for(code)
          next unless outcome

          yield(*outcome)
          return if outcome.last == :waf_blocked
        end
      end

      # @return [Array<String>] codes confirmed to exist (live or cached).
      def codes
        each_concept.filter_map do |code, _, status|
          code if %i[ok skipped].include?(status)
        end
      end

      private

      def outcome_for(code)
        cached = read_cache(code)
        return [code, cached, :skipped] if cached

        probe_one(code)
      end

      def probe_one(code)
        html = fetch(code)
        return nil unless html && @validator.valid?(html, code)

        [code, html, :ok]
      rescue Waf::Error => e
        warn "IEV: #{e.message} for #{code}"
        @options.store&.mark_failed(code, status: :waf_blocked)
        [code, nil, :waf_blocked]
      end

      def read_cache(code)
        store = @options.store
        return nil unless store && !@options.refresh

        store.concept_cached?(code) ? store.get_concept(code) : nil
      end

      def fetch(code)
        Waf.fetch_with_retry { @fetcher.fetch(concept_url(code)) }
      end

      def concept_url(code)
        "#{Iev::Scraper::BASE_URL}#{code}"
      end
    end
  end
end
