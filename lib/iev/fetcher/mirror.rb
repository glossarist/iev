# frozen_string_literal: true

require "nokogiri"

module Iev
  module Fetcher
    # Orchestrates mirroring of Electropedia concept pages into a PageStore.
    #
    # Walks a Scope section by section. For each section: sequentially
    # probe concept codes from <section>-01 upward, fetching and caching
    # each valid page until the first placeholder response, which marks
    # the end of the section.
    #
    # Single-threaded by design. The iterator is structured so a future
    # ConcurrentMirror can wrap the same work items without rewriting this
    # class (see TODO.next/02).
    class Mirror
      FETCH_DELAY = 5
      DEFAULT_JITTER = 0.4

      # Run-tuning knobs for Mirror. Kept as a value object so the Mirror
      # constructor stays under the parameter-list limit and callers can
      # pass the same options across mirror + reparse invocations.
      #
      # jitter is the ±fraction applied to delay each iteration to evade
      # naive rate-pattern detection: with delay=5, jitter=0.4, each
      # sleep is between 3s and 7s.
      Options = Struct.new(:limit, :refresh, :delay, :jitter, :on_progress,
                           keyword_init: true) do
        def initialize(limit: nil, refresh: false, delay: FETCH_DELAY,
                       jitter: DEFAULT_JITTER, on_progress: nil)
          super
        end
      end

      # @param scope [Scope] sections to mirror.
      # @param store [PageStore] injectable; defaults to a fresh PageStore.
      # @param fetcher [#fetch(url)] injectable; defaults to nil, in which
      #   case Mirror opens one Iev::Scraper::Browser::Session per run and
      #   reuses it for every fetch. AWS WAF's challenge cookie then
      #   persists across requests, raising the per-fetch success rate
      #   from ~60% (fresh browser each time) to ~100%.
      # @param validator [#valid?(html, code)] injectable; defaults to
      #   ConceptValidator.
      # @param options [Options] run-tuning knobs (limit, refresh, delay,
      #   on_progress callback).
      def initialize(scope:, store: PageStore.new,
                     fetcher: nil,
                     validator: ConceptValidator.new,
                     options: Options.new)
        @scope = scope
        @store = store
        @fetcher = fetcher
        @validator = validator
        @options = options
        @fetched = 0
      end

      attr_reader :fetched

      def run
        own_fetcher = @fetcher.nil?
        @fetcher = Source::Archive.new if own_fetcher
        begin
          each_section_with_progress
          self
        ensure
          @fetcher.quit if own_fetcher
        end
      end

      def each_section_with_progress
        total = @scope.sections.size
        @scope.each_section.with_index(1) do |section, idx|
          probe_section(section)
          progress(idx, total, section.code, :section_done)
        end
      end

      private

      def probe_section(section)
        build_probe(section).each_concept do |code, html, status|
          return if limit_reached?

          record_concept(code, html, status)
          throttle if status == :ok && !limit_reached?
        end
      end

      def build_probe(section)
        probe_options = SequentialProbe::Options.new(
          store: @store, refresh: @options.refresh,
        )
        SequentialProbe.new(section.code,
                            fetcher: @fetcher,
                            validator: @validator,
                            options: probe_options)
      end

      def record_concept(code, html, status)
        case status
        when :ok
          @store.put_concept(code, html)
          @fetched += 1
        when :skipped, :waf_blocked
          # skipped: already in store. waf_blocked: probe already recorded
          # the failure via PageStore#mark_failed.
        end
        progress(nil, nil, code, status)
      end

      def limit_reached?
        @options.limit && @fetched >= @options.limit
      end

      def throttle
        sleep delay_with_jitter
      end

      def delay_with_jitter
        base = @options.delay
        jitter = @options.jitter
        base * (1.0 - jitter + (rand * jitter * 2.0))
      end

      def progress(section_idx, total, code, status)
        @options.on_progress&.call(section_idx, total, code, status)
      end
    end
  end
end
