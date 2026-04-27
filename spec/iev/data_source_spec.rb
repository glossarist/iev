# frozen_string_literal: true

RSpec.describe Iev::DataSource do
  let(:fixture_concepts_path) { fixture_path("concepts") }

  before(:each) do
    Iev.reset_config!
    Iev.configure do |config|
      config.data_path = fixture_concepts_path
      config.cache_dir = File.join(Dir.tmpdir, "iev-test-cache-#{$$}")
    end
  end

  after(:each) do
    FileUtils.rm_rf(Iev.config.cache_dir)
    Iev.reset_config!
  end

  describe ".fetch_concept" do
    it "returns full concept data for a valid code" do
      concept = described_class.fetch_concept("103-01-02")
      expect(concept).not_to be_nil
      expect(concept["termid"]).to eq("103-01-02")
      expect(concept["term"]).to eq("functional")
    end

    it "includes multilingual data" do
      concept = described_class.fetch_concept("103-01-02")
      expect(concept).to have_key("eng")
      expect(concept).to have_key("deu")
      expect(concept).to have_key("fra")
    end

    it "returns nil for non-existent code" do
      concept = described_class.fetch_concept("999-99-99")
      expect(concept).to be_nil
    end
  end

  describe ".fetch_term" do
    it "returns localized data for a valid code and 3-char language" do
      term = described_class.fetch_term("103-01-02", "eng")
      expect(term).not_to be_nil
      expect(term["language_code"]).to eq("eng")
      expect(term["terms"][0]["designation"]).to eq("functional")
    end

    it "returns localized data when using 2-char language code" do
      term = described_class.fetch_term("103-01-02", "en")
      expect(term).not_to be_nil
      expect(term["terms"][0]["designation"]).to eq("functional")
    end

    it "returns German data" do
      term = described_class.fetch_term("103-01-02", "deu")
      expect(term).not_to be_nil
      expect(term["terms"][0]["designation"]).to eq("Funktional")
    end

    it "returns nil for non-existent code" do
      term = described_class.fetch_term("999-99-99", "eng")
      expect(term).to be_nil
    end

    it "returns nil for non-existent language" do
      term = described_class.fetch_term("103-01-02", "xxx")
      expect(term).to be_nil
    end
  end

  describe ".fetch_term_designation" do
    it "returns the preferred term designation" do
      result = described_class.fetch_term_designation("103-01-02", "en")
      expect(result).to eq("functional")
    end

    it "returns German designation" do
      result = described_class.fetch_term_designation("103-01-02", "de")
      expect(result).to eq("Funktional")
    end

    it "returns nil for non-existent code" do
      result = described_class.fetch_term_designation("999-99-99", "en")
      expect(result).to be_nil
    end

    it "returns nil for non-existent language" do
      result = described_class.fetch_term_designation("103-01-02", "xxx")
      expect(result).to be_nil
    end
  end
end

RSpec.describe Iev::Config do
  after(:each) do
    Iev.reset_config!
  end

  it "has sensible defaults" do
    config = described_class.new
    expect(config.remote_base_url).to include("glossarist-data-iev")
    expect(config.data_path).to eq(ENV["IEV_DATA_PATH"])
  end

  it "allows configuration via block" do
    Iev.configure do |config|
      config.data_path = "/custom/path"
    end
    expect(Iev.config.data_path).to eq("/custom/path")
  end

  it "reads IEV_DATA_PATH from environment" do
    ENV["IEV_DATA_PATH"] = "/env/path"
    config = described_class.new
    expect(config.data_path).to eq("/env/path")
  ensure
    ENV.delete("IEV_DATA_PATH")
  end
end
