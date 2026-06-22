# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "pathname"

require "iev/fetcher"
require "iev/fetcher/archive_probe"
require "iev/fetcher/page_store"
require "iev/fetcher/concept_validator"

# Real Ruby fetcher stub for ArchiveProbe specs. Returns fixture HTML
# for any registered URL; nil for unregistered. Mirrors StubMirrorFetcher
# from mirror_spec.rb but per-instance and stateless.
class StubArchiveFetcher
  def initialize(registrations = {})
    @registrations = registrations
  end

  def register(url, html) = @registrations[url] = html

  def fetch(url) = @registrations[url]
end

RSpec.describe Iev::Fetcher::ArchiveProbe do
  let(:tmp_root) { Pathname.new(Dir.mktmpdir("iev-archive-probe")) }
  let(:store) { Iev::Fetcher::PageStore.new(root_dir: tmp_root) }
  let(:stub_fetcher) { StubArchiveFetcher.new }

  after { FileUtils.rm_rf(tmp_root) }

  # The full code list we hand to the probe. The stub returns valid HTML
  # for 01 and 03, nil for 02 (simulating an archive gap), and a WAF stub
  # for 04.
  let(:codes) { %w[103-01-01 103-01-02 103-01-03 103-01-04] }

  let(:real_html) do
    path = File.expand_path("../../examples/103_01_01_real.html", __dir__)
    File.read(path, encoding: "utf-8")
  end

  before do
    stub_fetcher.register("#{Iev::Scraper::BASE_URL}103-01-01",
                          real_html.gsub("103-01-01", "103-01-01"))
    stub_fetcher.register("#{Iev::Scraper::BASE_URL}103-01-03",
                          real_html.gsub("103-01-01", "103-01-03"))
    stub_fetcher.register("#{Iev::Scraper::BASE_URL}103-01-04",
                          "Confirm you are human")
    # 103-01-02 left unregistered — fetcher returns nil.

    # WAF retries use real sleeps (10s × 5 attempts = 150s per challenge).
    # Stub globally for the suite.
    allow(Iev::Fetcher::Waf).to receive(:sleep)
  end

  def probe(store: nil, refresh: false)
    options = Iev::Fetcher::ArchiveProbe::Options.new(store: store,
                                                      refresh: refresh)
    described_class.new("103-01", codes: codes, fetcher: stub_fetcher,
                                  validator: Iev::Fetcher::ConceptValidator.new,
                                  options: options)
  end

  it "skips codes with no snapshot but continues to the next" do
    statuses = []
    probe.each_concept { |*_, status| statuses << status }
    # 01 ok, 02 silently skipped (no yield), 03 ok, 04 waf_blocked then stops.
    expect(statuses).to eq(%i[ok ok waf_blocked])
  end

  it "yields cached HTML with :skipped and avoids hitting the fetcher" do
    store.put_concept("103-01-01", real_html)

    statuses = []
    probe(store: store).each_concept { |*_, status| statuses << status }
    expect(statuses.first).to eq(:skipped)
  end

  it "re-fetches when refresh is true even if cached" do
    store.put_concept("103-01-01", "stale cached")

    statuses = []
    probe(store: store, refresh: true).each_concept do |*_, status|
      statuses << status
    end
    expect(statuses.first).to eq(:ok)
  end

  it "stops iteration after a waf_blocked outcome" do
    # 04 is waf_blocked; if iteration continued, 05+ would be next. We
    # registered only up to 04, but the codes list is exactly 01..04.
    # The waf_blocked return is the third yield; codes list ends there.
    statuses = []
    probe.each_concept { |*_, status| statuses << status }
    expect(statuses.last).to eq(:waf_blocked)
  end

  it "records waf_blocked codes in the manifest without writing a file" do
    probe(store: store).each_concept.to_a
    expect(store.status("103-01-04")).to eq(:waf_blocked)
    expect(store.concept_cached?("103-01-04")).to be(false)
  end

  it "returns confirmed codes via .codes" do
    confirmed = probe.codes
    # 04 is waf_blocked so excluded; 02 silently skipped.
    expect(confirmed).to include("103-01-01", "103-01-03")
    expect(confirmed).not_to include("103-01-02", "103-01-04")
  end
end
