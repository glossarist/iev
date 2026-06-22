# frozen_string_literal: true

require "ferrum"

module Iev
  class Scraper
    # Shared headless browser utilities for fetching pages behind AWS WAF.
    module Browser
      # Each profile is tagged with the host platform it can run on so
      # that navigator.platform (set by Chrome from the real OS) agrees
      # with the User-Agent and Sec-Ch-Ua-Platform headers. AWS WAF
      # fingerprints this mismatch and refuses to clear its challenge.
      USER_AGENT_PROFILES = [
        {
          user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/131.0.0.0 Safari/537.36",
          platform: '"macOS"',
          chrome_version: "131",
          host_platform: :mac,
        },
        {
          user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/129.0.0.0 Safari/537.36",
          platform: '"macOS"',
          chrome_version: "129",
          host_platform: :mac,
        },
        {
          user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/130.0.0.0 Safari/537.36",
          platform: '"Windows"',
          chrome_version: "130",
          host_platform: :windows,
        },
        {
          user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/131.0.0.0 Safari/537.36",
          platform: '"Windows"',
          chrome_version: "131",
          host_platform: :windows,
        },
        {
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/131.0.0.0 Safari/537.36",
          platform: '"Linux"',
          chrome_version: "131",
          host_platform: :linux,
        },
      ].freeze

      DEFAULT_LANG = "en-US,en"
      DEFAULT_BROWSER_OPTIONS = {
        "disable-blink-features" => "AutomationControlled",
        "lang" => DEFAULT_LANG,
      }.freeze

      # One-shot fetch. Each call spins up a fresh headless Chrome, fetches,
      # and tears it down. Suitable for ad-hoc use; the WAF cookie does not
      # survive between calls. Batch callers (Fetcher::Mirror) should use
      # Session instead so the cookie set on the first successful challenge
      # is reused across requests.
      def self.fetch(url, **_browser_opts)
        Session.new.fetch(url)
      end

      # Returns request headers that match what real Chrome sends on a
      # fresh address-bar navigation. AWS WAF fingerprints inconsistencies
      # between these headers and the browser's runtime state, so we:
      #   - omit Sec-Fetch-* (Chrome computes those itself from the
      #     navigation context; setting them via Ferrum's Network domain
      #     overrides the real values and is detectable), and
      #   - keep Sec-Ch-Ua-Platform aligned with the host OS, which is
      #     what Chrome reports via navigator.platform.
      def self.random_headers
        profile = profile_for_host
        static_headers.merge(headers_from_profile(profile))
      end

      def self.static_headers
        {
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9," \
                      "image/avif,image/webp,image/apng,*/*;q=0.8," \
                      "application/signed-exchange;v=b3;q=0.7",
          "Accept-Language" => "en-US,en;q=0.9",
          "Cache-Control" => "no-cache",
          "Pragma" => "no-cache",
          "Sec-Ch-Ua-Mobile" => "?0",
          "Upgrade-Insecure-Requests" => "1",
        }
      end

      def self.headers_from_profile(profile)
        {
          "Sec-Ch-Ua" => sec_ch_ua_for(profile),
          "Sec-Ch-Ua-Platform" => profile[:platform],
          "User-Agent" => profile[:user_agent],
        }
      end

      def self.profile_for_host
        USER_AGENT_PROFILES.select do |profile|
          profile[:host_platform] == host_platform
        end.sample
      end

      def self.host_platform
        case RUBY_PLATFORM
        when /darwin/ then :mac
        when /mswin|mingw|cygwin|bccwin|wince|emx/ then :windows
        else :linux
        end
      end

      def self.sec_ch_ua_for(profile)
        "\"Google Chrome\";v=\"#{profile[:chrome_version]}\", " \
          "\"Chromium\";v=\"#{profile[:chrome_version]}\", " \
          "\"Not_A Brand\";v=\"24\""
      end

      # A long-lived headless Chrome session. Cookies persist across
      # fetches, so once the AWS WAF challenge is cleared on the first
      # request, subsequent requests reuse the token and succeed at
      # near-100% rate. The Mirror creates one Session per run and
      # shares it across all SequentialProbe iterations.
      class Session
        def initialize
          @browser = Ferrum::Browser.new(
            headless: "new",
            timeout: 30,
            window_size: [1366, 768],
            browser_options: Browser::DEFAULT_BROWSER_OPTIONS,
          )
          @browser.headers.set(Browser.random_headers)
        end

        def fetch(url)
          @browser.go_to(url)
          @browser.network.wait_for_idle(timeout: 15)
          reject_blocked(url, @browser.body)
        rescue Ferrum::Error, Ferrum::BrowserError => e
          warn "IEV: Browser error fetching #{url}: #{e.message}"
          nil
        end

        def reject_blocked(url, html)
          if html.include?("403 ERROR") || html.include?("Request blocked")
            warn "IEV: AWS WAF blocked request for #{url}"
            nil
          else
            html
          end
        end

        def quit
          @browser&.quit
        end
      end
    end
  end
end
