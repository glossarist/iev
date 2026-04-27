# frozen_string_literal: true

RSpec.describe Iev do
  before :each do
    Iev.reset_config!
    Iev.configure do |config|
      config.data_path = fixture_path("concepts")
    end
  end

  after :each do
    Iev.reset_config!
  end

  it "has a version number" do
    expect(Iev::VERSION).not_to be nil
  end

  describe "Iev.get (backward compatible)" do
    it "returns term designation from local data" do
      expect(Iev.get("103-01-02", "en")).to eq("functional")
    end

    it "returns nil for non-existent code" do
      expect(Iev.get("999-99-99", "en")).to be_nil
    end
  end

  describe "Iev.fetch_concept" do
    it "returns full concept data" do
      concept = Iev.fetch_concept("103-01-02")
      expect(concept["termid"]).to eq("103-01-02")
      expect(concept["term"]).to eq("functional")
    end
  end

  describe "Iev.fetch_term" do
    it "returns localized concept data" do
      term = Iev.fetch_term("103-01-02", "eng")
      expect(term["terms"][0]["designation"]).to eq("functional")
      expect(term["definition"]).to include("function for which")
    end
  end
end
