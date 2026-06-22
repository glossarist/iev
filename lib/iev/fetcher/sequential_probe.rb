# frozen_string_literal: true

module Iev
  module Fetcher
    # Lists concept codes that exist within a section by probing
    # `display?openform&ievref=<section>-NN` sequentially from 01.
    #
    # The Electropedia area-level browse URL (`index?openform&part=<area>`)
    # lists sections, but the section-level equivalent does not exist —
    # requesting it returns HTTP 404. Sequential probing is the only way
    # to enumerate a section's concepts. Stops at the first not-found,
    # which assumes IEV codes are contiguously assigned from 01 within a
    # section. If a section is known to have gaps, the cache will retain
    # the contiguous prefix only.
    class SequentialProbe
      MAX_NUMBER = 99

      # Optional knobs for SequentialProbe, bundled so the constructor
      # stays under the parameter-list limit.
      Options = Struct.new(:store, :refresh, :max_number,
                           keyword_init: true) do
        def initialize(store: nil, refresh: false,
                       max_number: MAX_NUMBER)
          super
        end
      end

      # @param section_code [String] e.g. "103-01"
      # @param fetcher [Module] responds to +.fetch(url) -> html+.
      # @param validator [#valid?(html, code)] distinguishes real concepts
      #   from placeholder pages.
      # @param options [Options] cache, refresh, max_number tuning.
      def initialize(section_code, fetcher:, validator:, options: Options.new)
        @section_code = section_code.to_s
        @fetcher = fetcher
        @validator = validator
        @options = options
      end

      # Yields (code, html, status) for each probe outcome in sequence.
      # Status is one of:
      #   - :ok          — html was fetched live and validated.
      #   - :skipped     — code was already cached; html is the cached body.
      #   - :waf_blocked — fetch hit an uncleared WAF challenge; html is nil.
      #
      # Stops iterating at the first code that does not exist (no yield)
      # or after yielding :waf_blocked (the section may have more codes,
      # but we cannot reach them until the WAF clears).
      def each_concept
        return enum_for(:each_concept) unless block_given?

        1.upto(@options.max_number) do |number|
          code = code_for(number)
          outcome = outcome_for(code)
          return unless outcome

          yield(*outcome)
          return if outcome.last == :waf_blocked
        end
      end

      # @return [Array<String>] concept codes confirmed to exist in this
      #   section (either fetched live with :ok or already cached).
      def codes
        each_concept.filter_map do |code, _, status|
          code if %i[ok skipped].include?(status)
        end
      end

      private

      # Resolves one code to a yield tuple (or nil to end iteration).
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

      def code_for(number)
        format("%<section>s-%02<number>d",
               section: @section_code, number: number)
      end

      def concept_url(code)
        "#{Iev::Scraper::BASE_URL}#{code}"
      end
    end
  end
end
