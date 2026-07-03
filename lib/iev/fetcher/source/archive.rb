# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Iev
  module Fetcher
    module Source
      # Fetches Electropedia concept pages via the Internet Archive's
      # Wayback Machine. Bypasses IEC's AWS WAF entirely because
      # archive.org serves snapshots over plain HTTPS — no headless
      # browser, no challenge.js, no fingerprinting.
      #
      # Two HTTP calls per fetch: (1) availability API to find the
      # closest snapshot, (2) the snapshot itself using the `id_` URL
      # modifier which returns the original response bytes without
      # Wayback's toolbar/wrapper. The returned HTML has the same DOM
      # structure as a live fetch, so PageParser consumes it unchanged.
      class Archive
        AVAILABILITY_API = "https://archive.org/wayback/available?url=%<url>s"
        DEFAULT_MIN_TIMESTAMP = "20250101"
        DEFAULT_OPEN_TIMEOUT = 10
        DEFAULT_READ_TIMEOUT = 15

        # Wraps Net::HTTP so the parser logic above stays pure and
        # injectable for specs. Real Ruby class — not a double.
        class Transport
          def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT,
                         read_timeout: DEFAULT_READ_TIMEOUT)
            @open_timeout = open_timeout
            @read_timeout = read_timeout
          end

          def get(url)
            uri = URI(url)
            https_request(uri) do |http|
              response = http.get(uri.request_uri)
              return nil unless response.is_a?(Net::HTTPSuccess)

              # Net::HTTP labels response bodies as ASCII-8BIT regardless of
              # the actual charset. archive.org serves UTF-8 HTML; force the
              # encoding so downstream File.write / Digest::SHA256 / Nokogiri
              # callers see a UTF-8 String, matching Ferrum's behavior.
              response.body.force_encoding("utf-8")
            end
          rescue StandardError => e
            warn "IEV: archive.org GET failed for #{url}: #{e.message}"
            nil
          end

          def https_request(uri, &)
            Net::HTTP.start(uri.host, uri.port,
                            use_ssl: uri.scheme == "https",
                            open_timeout: @open_timeout,
                            read_timeout: @read_timeout, &)
          end
        end

        # @param min_timestamp [String] reject snapshots older than this
        #   (YYYYMMDD). Default accepts any snapshot from 2025 onward.
        # @param transport [#get(url) -> String, nil] HTTP client used for
        #   both the availability API and the snapshot fetch. Injectable
        #   for specs.
        def initialize(min_timestamp: DEFAULT_MIN_TIMESTAMP,
                       transport: Transport.new)
          @min_timestamp = min_timestamp
          @transport = transport
        end

        # @param url [String] the live Electropedia URL to mirror.
        # @return [String, nil] original HTML from the closest acceptable
        #   snapshot, or nil if no snapshot exists, the snapshot is older
        #   than min_timestamp, or the snapshot body is a WAF stub that
        #   archive.org mistakenly captured.
        def fetch(url)
          snapshot = closest_snapshot(url) or return nil
          return nil if snapshot["timestamp"] < @min_timestamp

          html = @transport.get(snapshot_id_url(snapshot))
          return nil unless html
          return nil if Waf.challenge?(html)

          html
        end

        # No-op; Net::HTTP has no persistent state to release. Satisfies
        # the Source protocol alongside Browser::Session#quit.
        def quit; end

        private

        def closest_snapshot(url)
          body = @transport.get(format(AVAILABILITY_API,
                                       url: URI.encode_www_form_component(url)))
          return nil unless body

          parsed = JSON.parse(body)
          snapshot = parsed.dig("archived_snapshots", "closest")
          return nil unless snapshot&.dig("available")

          snapshot
        rescue JSON::ParserError => e
          warn "IEV: archive.org availability JSON parse error: #{e.message}"
          nil
        end

        # Injects the `id_` modifier after the timestamp so Wayback
        # returns the original bytes rather than its toolbar-wrapped
        # variant. E.g. /web/20251118.../ -> /web/20251118...id_/
        #
        # Also force HTTPS: the availability API returns HTTP URLs but
        # archive.org refuses port 80 connections, so an HTTP snapshot
        # URL fails with "Connection refused".
        def snapshot_id_url(snapshot)
          ts = snapshot["timestamp"]
          url = snapshot["url"].sub("/web/#{ts}/", "/web/#{ts}id_/")
          url.sub(/\Ahttp:/, "https:")
        end
      end
    end
  end
end
