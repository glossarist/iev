# frozen_string_literal: true

require "nokogiri"

module Iev
  class Scraper
    autoload :Browser, "iev/scraper/browser"
    autoload :PageParser, "iev/scraper/page_parser"

    BASE_URL = "https://www.electropedia.org/iev/iev.nsf/" \
               "display?openform&ievref="

    def initialize(browser_opts: {})
      @browser_opts = browser_opts
    end

    # Fetch the Electropedia page HTML for a given IEV code.
    # Returns a Nokogiri document.
    def fetch_page(code)
      html = Browser.fetch("#{BASE_URL}#{code}",
                           browser_opts: @browser_opts)
      return nil unless html

      Nokogiri::HTML(html)
    end

    # Fetch and parse concept data for an IEV code.
    # Returns a hash with concept data or nil if not found.
    def fetch_concept(code)
      doc = fetch_page(code)
      return nil unless doc

      PageParser.new(doc, code).parse
    end
  end
end
