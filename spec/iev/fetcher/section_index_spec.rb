# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "iev/fetcher"
require "iev/fetcher/section_index"

# A real Ruby module that pretends to be a fetcher for tests.
# Implements the same contract as Iev::Scraper::Browser.fetch.
module StubFetcher
  module_function

  def fetch(url)
    responses[url]
  end

  def responses
    @responses ||= {}
  end

  def reset
    @responses = {}
  end

  def register(url, html)
    responses[url] = html
  end
end

RSpec.describe Iev::Fetcher::SectionIndex do
  let(:section_html) do
    File.read(File.expand_path("../../examples/section_103_01.html", __dir__),
              encoding: "utf-8")
  end

  let(:section_url) do
    format(described_class::SECTION_INDEX_URL, section: "103-01")
  end

  before { StubFetcher.reset }

  describe "#concept_codes_from" do
    it "extracts sorted unique concept codes from the section HTML" do
      index = described_class.new("103-01", fetcher: StubFetcher)
      codes = index.concept_codes_from(section_html)
      expect(codes).to start_with("103-01-01")
      expect(codes).to include("103-01-02", "103-01-03")
      expect(codes.length).to be > 1
      expect(codes).to eq(codes.sort.uniq)
    end

    it "returns an empty array for nil input" do
      index = described_class.new("103-01", fetcher: StubFetcher)
      expect(index.concept_codes_from(nil)).to eq([])
    end

    it "deduplicates codes" do
      html = <<~HTML
        <html><body>
        <a href="/display?openform&ievref=103-01-01">103-01-01</a>
        <a href="/display?openform&ievref=103-01-01">103-01-01</a>
        <a href="/display?openform&ievref=103-01-02">103-01-02</a>
        </body></html>
      HTML
      index = described_class.new("103-01", fetcher: StubFetcher)
      expect(index.concept_codes_from(html)).to eq(%w[103-01-01 103-01-02])
    end

    it "ignores non-concept-shaped codes" do
      html = <<~HTML
        <html><body>
        <a href="/display?openform&ievref=103-01">103-01</a>
        <a href="/display?openform&ievref=103">103</a>
        <a href="/display?openform&ievref=103-01-02">103-01-02</a>
        </body></html>
      HTML
      index = described_class.new("103-01", fetcher: StubFetcher)
      expect(index.concept_codes_from(html)).to eq(["103-01-02"])
    end
  end

  describe "#concept_codes" do
    it "fetches and parses the section browse page" do
      StubFetcher.register(section_url, section_html)
      index = described_class.new("103-01", fetcher: StubFetcher)
      codes = index.concept_codes
      expect(codes).to start_with("103-01-01")
      expect(codes).to include("103-01-02", "103-01-03")
    end

    it "returns an empty array when the fetcher returns nil" do
      StubFetcher.register(section_url, nil)
      index = described_class.new("103-01", fetcher: StubFetcher)
      expect(index.concept_codes).to eq([])
    end
  end
end
