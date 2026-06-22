# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "pathname"

require "iev/fetcher"
require "iev/fetcher/sequential_probe"
require "iev/fetcher/page_store"
require "iev/fetcher/concept_validator"

# In-process fetcher stub. Returns registered HTML for a URL; for concept
# URLs without an explicit registration, returns the real 103-01-01
# fixture if the URL ends in -01, otherwise the placeholder fixture so
# the validator rejects it. Records every URL it was asked for.
class StubProbeFetcher
  def initialize
    @responses = {}
    @fetched_urls = []
  end

  attr_reader :fetched_urls

  def register(url, html) = @responses[url] = html

  def fetch(url)
    @fetched_urls << url
    return @responses[url] if @responses.key?(url)

    code = url[/ievref=([\d-]+)/, 1]
    return nil unless code

    if code.end_with?("-01")
      File.read(File.expand_path("../../examples/103_01_01_real.html",
                                 __dir__), encoding: "utf-8")
    else
      File.read(File.expand_path("../../examples/103_01_99_placeholder.html",
                                 __dir__), encoding: "utf-8")
    end
  end
end

# Captures (url, html) pairs so a test can pretend to be a fetcher while
# recording what was asked of it.
class RecordingFetcher
  def initialize(returning:, into:)
    @returning = returning
    @into = into
  end

  def fetch(url)
    @into << url
    @returning
  end
end

RSpec.describe Iev::Fetcher::SequentialProbe do
  let(:validator) { Iev::Fetcher::ConceptValidator.new }
  let(:real_html) do
    File.read(File.expand_path("../../examples/103_01_01_real.html", __dir__),
              encoding: "utf-8")
  end
  let(:placeholder_html) do
    File.read(File.expand_path("../../examples/103_01_99_placeholder.html",
                               __dir__), encoding: "utf-8")
  end
  let(:stub_fetcher) { StubProbeFetcher.new }

  def probe(store: nil, fetcher: stub_fetcher, **)
    options = described_class::Options.new(store: store, **)
    described_class.new("103-01",
                        fetcher: fetcher,
                        validator: validator,
                        options: options)
  end

  it "stops at the first code that returns a placeholder" do
    stub_fetcher.register(
      "#{Iev::Scraper::BASE_URL}103-01-02",
      placeholder_html,
    )
    codes = probe.codes
    expect(codes).to eq(["103-01-01"])
  end

  it "yields (code, html, :ok) for live fetches" do
    yielded = []
    probe.each_concept { |code, _, status| yielded << [code, status] }
    expect(yielded.first).to eq(["103-01-01", :ok])
  end

  it "returns cached codes as :skipped without fetching" do
    tmp_root = Pathname.new(Dir.mktmpdir("iev-probe"))
    begin
      store = Iev::Fetcher::PageStore.new(root_dir: tmp_root)
      store.put_concept("103-01-01", real_html)

      fetched_urls = []
      fetcher = RecordingFetcher.new(returning: real_html, into: fetched_urls)

      options = described_class::Options.new(store: store)
      result = described_class.new("103-01",
                                   fetcher: fetcher,
                                   validator: validator,
                                   options: options).each_concept.to_a
      expect(result.first).to eq(["103-01-01", real_html, :skipped])
      # 103-01-01 came from cache; 103-01-02 is fetched live to find the
      # boundary, then rejected because real_html has the wrong IEV ref.
      expect(fetched_urls).to eq(["#{Iev::Scraper::BASE_URL}103-01-02"])
    ensure
      FileUtils.rm_rf(tmp_root)
    end
  end

  it "re-fetches cached codes when refresh is true" do
    tmp_root = Pathname.new(Dir.mktmpdir("iev-probe"))
    begin
      store = Iev::Fetcher::PageStore.new(root_dir: tmp_root)
      store.put_concept("103-01-01", real_html)

      fetched_urls = []
      fetcher = RecordingFetcher.new(returning: real_html, into: fetched_urls)

      options = described_class::Options.new(store: store, refresh: true)
      described_class.new("103-01",
                          fetcher: fetcher,
                          validator: validator,
                          options: options).codes
      expect(fetched_urls).to include("#{Iev::Scraper::BASE_URL}103-01-01")
    ensure
      FileUtils.rm_rf(tmp_root)
    end
  end

  it "respects the max_number bound" do
    (2..99).each do |n|
      code = "103-01-#{format('%02d', n)}"
      stub_fetcher.register(
        "#{Iev::Scraper::BASE_URL}#{code}",
        real_html.gsub("103-01-01", code),
      )
    end
    codes = probe(max_number: 99).codes
    expect(codes.last).to eq("103-01-99")
  end
end
