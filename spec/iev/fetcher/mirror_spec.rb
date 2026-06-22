# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "pathname"

require "iev/fetcher"
require "iev/fetcher/mirror"
require "iev/fetcher/page_store"
require "iev/fetcher/scope"
require "iev/fetcher/concept_validator"

# Real Ruby class that fakes Iev::Scraper::Browser for Mirror specs.
# Returns explicitly registered HTML for a URL. For concept-page URLs
# without a registration, templates the 103-01-01 fixture per code so
# the validator accepts codes 01..boundary and rejects boundary+1.
class StubMirrorFetcher
  def initialize
    @responses = {}
  end

  def register(url, html) = @responses[url] = html

  def fetch(url)
    return @responses[url] if @responses.key?(url)

    generate(url)
  end

  def generate(url)
    code = url[/ievref=([\d-]+)/, 1]
    return nil unless code

    # Codes 01..05 are valid; 06+ are placeholders (no localized_concepts).
    if code.end_with?("-01", "-02", "-03", "-04", "-05")
      real_template.gsub("103-01-01", code)
    else
      placeholder_template
    end
  end

  def real_template
    @real_template ||= begin
      path = File.expand_path("../../examples/103_01_01_real.html", __dir__)
      File.read(path, encoding: "utf-8")
    end
  end

  def placeholder_template
    @placeholder_template ||= begin
      path = File.expand_path("../../examples/103_01_99_placeholder.html",
                              __dir__)
      File.read(path, encoding: "utf-8")
    end
  end
end

RSpec.describe Iev::Fetcher::Mirror do
  let(:tmp_root) { Pathname.new(Dir.mktmpdir("iev-mirror")) }
  let(:store) { Iev::Fetcher::PageStore.new(root_dir: tmp_root) }
  let(:stub_fetcher) { StubMirrorFetcher.new }
  let(:scope) { Iev::Fetcher::Scope.for_section("103-01") }

  # The stub returns valid HTML for codes 01..05, placeholder for 06+.
  let(:concept_codes) { %w[103-01-01 103-01-02 103-01-03 103-01-04 103-01-05] }

  after { FileUtils.rm_rf(tmp_root) }

  def mirror(delay: 0, **)
    Iev::Fetcher::Mirror.new(
      scope: scope,
      store: store,
      fetcher: stub_fetcher,
      options: Iev::Fetcher::Mirror::Options.new(delay: delay, **),
    )
  end

  it "probes and caches every concept in the section" do
    m = mirror.run
    expect(m.fetched).to eq(concept_codes.length)
    concept_codes.each do |code|
      expect(store.concept_cached?(code)).to be(true)
    end
  end

  it "invokes the progress callback with :ok and :section_done" do
    events = []
    mirror(on_progress: ->(*args) { events << args }).run
    statuses = events.map { |e| e[3] }
    expect(statuses).to include(:ok, :section_done)
  end

  it "skips concepts that are already cached" do
    store.put_concept("103-01-01", stub_fetcher.real_template)

    statuses = []
    mirror(on_progress: ->(*args) { statuses << args[3] }).run

    expect(statuses).to include(:skipped)
    expect(store.status("103-01-01")).to eq(:ok)
  end

  it "honours the limit option" do
    m = mirror(limit: 2).run
    expect(m.fetched).to eq(2)
  end

  it "re-fetches when refresh is true" do
    cached_html = stub_fetcher.real_template
    store.put_concept("103-01-01", cached_html)

    m = mirror(refresh: true).run
    # 5 codes are all live-fetched under refresh.
    expect(m.fetched).to eq(concept_codes.length)
    expect(store.status("103-01-01")).to eq(:ok)
  end

  it "records a WAF-blocked code in the manifest without writing a file" do
    stub_fetcher.register(
      "#{Iev::Scraper::BASE_URL}103-01-03",
      "Confirm you are human",
    )
    allow(Iev::Fetcher::Waf).to receive(:sleep)
    mirror.run
    expect(store.status("103-01-03")).to eq(:waf_blocked)
    expect(store.concept_cached?("103-01-03")).to be(false)
  end
end
