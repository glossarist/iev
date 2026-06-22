# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require "pathname"

require "iev/fetcher"
require "iev/fetcher/page_store"
require "iev/fetcher/scope"

RSpec.describe Iev::Fetcher::PageStore do
  let(:tmp_root) { Pathname.new(Dir.mktmpdir("iev-page-store")) }
  let(:store) { described_class.new(root_dir: tmp_root) }

  after { FileUtils.rm_rf(tmp_root) }

  describe "#put_concept / #get_concept" do
    it "round-trips concept HTML" do
      store.put_concept("103-01-02", "<html>concept</html>")
      expect(store.get_concept("103-01-02")).to eq("<html>concept</html>")
    end

    it "returns nil for an unknown code" do
      expect(store.get_concept("999-99-99")).to be_nil
    end
  end

  describe "#concept_cached?" do
    it "is false before put_concept and true after" do
      expect(store.concept_cached?("103-01-02")).to be(false)
      store.put_concept("103-01-02", "<html>x</html>")
      expect(store.concept_cached?("103-01-02")).to be(true)
    end
  end

  describe "#put_section / #get_section / #section_cached?" do
    it "round-trips section HTML independently of concept pages" do
      store.put_section("103-01", "<html>section</html>")
      expect(store.section_cached?("103-01")).to be(true)
      expect(store.get_section("103-01")).to eq("<html>section</html>")
      expect(store.concept_cached?("103-01")).to be(false)
    end
  end

  describe "#status" do
    it "is :ok after a successful put" do
      store.put_concept("103-01-02", "<html>x</html>")
      expect(store.status("103-01-02")).to eq(:ok)
    end

    it "is :missing for an unknown code" do
      expect(store.status("999-99-99")).to eq(:missing)
    end

    it "is :waf_blocked after mark_failed" do
      store.mark_failed("103-01-02", status: :waf_blocked)
      expect(store.status("103-01-02")).to eq(:waf_blocked)
    end

    it "does not create an HTML file when mark_failed is called" do
      store.mark_failed("103-01-02", status: :waf_blocked)
      expect(store.concept_cached?("103-01-02")).to be(false)
    end
  end

  describe "manifest persistence" do
    it "writes manifest.json to the root dir" do
      store.put_concept("103-01-02", "<html>x</html>")
      manifest_path = tmp_root.join("manifest.json")
      expect(manifest_path).to exist
      data = JSON.parse(manifest_path.read)
      expect(data["103-01-02"]["status"]).to eq("ok")
    end

    it "reloads manifest entries on a new instance" do
      store.put_concept("103-01-02", "<html>x</html>")
      reopened = described_class.new(root_dir: tmp_root)
      expect(reopened.status("103-01-02")).to eq(:ok)
    end
  end

  describe "#each_concept" do
    before do
      store.put_concept("103-01-01", "<html>one</html>")
      store.put_concept("103-01-02", "<html>two</html>")
      store.put_concept("102-01-01", "<html>other section</html>")
    end

    it "yields [code, html] for every cached concept when scope is nil" do
      pairs = store.each_concept.to_a
      codes = pairs.map(&:first)
      expect(codes).to include("103-01-01", "103-01-02", "102-01-01")
    end

    it "filters by scope" do
      scope = Iev::Fetcher::Scope.for_section("103-01")
      pairs = store.each_concept(scope: scope).to_a
      expect(pairs.map(&:first)).to eq(%w[103-01-01 103-01-02])
    end

    it "returns an Enumerator when called without a block" do
      expect(store.each_concept).to be_a(Enumerator)
    end
  end
end
