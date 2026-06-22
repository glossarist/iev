# frozen_string_literal: true

require "nokogiri"

module Iev
  module Fetcher
    # Distinguishes real Electropedia concept pages from placeholder pages.
    #
    # Electropedia returns the same shell HTML for both real concepts and
    # never-assigned codes — the IEV ref is echoed from the URL into the
    # page, so a naive "did PageParser return anything?" check happily
    # accepts placeholders. The distinguishing signal is whether
    # `localized_concepts` is populated.
    class ConceptValidator
      def valid?(html, code)
        return false unless html

        parsed = Iev::Scraper::PageParser.new(Nokogiri::HTML(html), code).parse
        !!(parsed && parsed.dig("data", "localized_concepts")&.any?)
      end
    end
  end
end
