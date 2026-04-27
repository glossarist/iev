# frozen_string_literal: true

module Iev
  # Scrapes IEV term data from Electropedia (electropedia.org).
  #
  # Electropedia is behind AWS WAF which requires JavaScript execution,
  # so a headless browser (via Ferrum/Chrome) is used to handle the challenge.
  #
  # @example
  #   scraper = Iev::Scraper.new
  #   concept = scraper.fetch_concept("103-01-02")
  #   doc = scraper.fetch_page("103-01-02")
  class Scraper
    BASE_URL = "https://www.electropedia.org/iev/iev.nsf/" \
               "display?openform&ievref="

    # Pool of realistic Chrome User-Agent strings with matching platform hints.
    # Rotated per request to reduce fingerprinting by AWS WAF.
    USER_AGENT_PROFILES = [
      {
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "Chrome/131.0.0.0 Safari/537.36",
        platform: '"macOS"',
        chrome_version: "131",
      },
      {
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "Chrome/130.0.0.0 Safari/537.36",
        platform: '"Windows"',
        chrome_version: "130",
      },
      {
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "Chrome/131.0.0.0 Safari/537.36",
        platform: '"Linux"',
        chrome_version: "131",
      },
      {
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "Chrome/129.0.0.0 Safari/537.36",
        platform: '"macOS"',
        chrome_version: "129",
      },
      {
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) " \
                    "Chrome/131.0.0.0 Safari/537.36",
        platform: '"Windows"',
        chrome_version: "131",
      },
    ].freeze

    def initialize(browser_opts: {})
      @browser_opts = browser_opts
    end

    # Fetch the Electropedia page HTML for a given IEV code.
    # Returns a Nokogiri document.
    def fetch_page(code)
      require "ferrum"
      require "nokogiri"

      url = "#{BASE_URL}#{code}"
      browser = Ferrum::Browser.new(
        headless: "new",
        timeout: 30,
        window_size: [1366, 768],
        browser_options: {
          "disable-blink-features" => "AutomationControlled",
        },
        **@browser_opts,
      )

      browser.headers.set(random_headers)
      browser.go_to(url)
      browser.network.wait_for_idle(timeout: 15)
      html = browser.body

      # Check if we got a real page or a WAF block
      if html.include?("403 ERROR") || html.include?("Request blocked")
        warn "IEV Scraper: AWS WAF blocked request for #{code}"
        return nil
      end

      Nokogiri::HTML(html)
    rescue Ferrum::Error, Ferrum::BrowserError => e
      warn "IEV Scraper error for #{code}: #{e.message}"
      nil
    ensure
      browser&.quit
    end

    # Fetch and parse concept data for an IEV code.
    # Returns a hash with concept data or nil if not found.
    def fetch_concept(code)
      doc = fetch_page(code)
      return nil unless doc

      PageParser.new(doc, code).parse
    end

    private

    def random_headers
      profile = USER_AGENT_PROFILES.sample
      sec_ch_ua = "\"Google Chrome\";v=\"#{profile[:chrome_version]}\", " \
                  "\"Chromium\";v=\"#{profile[:chrome_version]}\", " \
                  "\"Not_A Brand\";v=\"24\""

      {
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9," \
                    "image/avif,image/webp,image/apng,*/*;q=0.8," \
                    "application/signed-exchange;v=b3;q=0.7",
        "Accept-Language" => "en-GB,en-US;q=0.9,en;q=0.8",
        "Cache-Control" => "no-cache",
        "Pragma" => "no-cache",
        "Sec-Ch-Ua" => sec_ch_ua,
        "Sec-Ch-Ua-Mobile" => "?0",
        "Sec-Ch-Ua-Platform" => profile[:platform],
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Site" => "cross-site",
        "Sec-Fetch-User" => "?1",
        "Upgrade-Insecure-Requests" => "1",
        "User-Agent" => profile[:user_agent],
      }
    end
  end
end

require_relative "scraper/page_parser"
