# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Section do
  subject(:section) do
    described_class.new(code: "103-01", title: "General functions",
                        area_code: "103")
  end

  it "exposes code" do
    expect(section.code).to eq("103-01")
  end

  it "exposes title" do
    expect(section.title).to eq("General functions")
  end

  it "exposes area_code" do
    expect(section.area_code).to eq("103")
  end

  it "returns URI" do
    expect(section.uri).to eq("section-103-01")
  end

  it "converts to hash" do
    expect(section.to_h).to eq({ "code" => "103-01",
                                 "title" => "General functions" })
  end

  it "coerces code to string" do
    section = described_class.new(code: 103, title: "Test", area_code: "103")
    expect(section.code).to eq("103")
  end

  describe "equality" do
    it "is equal when codes match" do
      a = described_class.new(code: "103-01", title: "A", area_code: "103")
      b = described_class.new(code: "103-01", title: "B", area_code: "104")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "is not equal when codes differ" do
      a = described_class.new(code: "103-01", title: "A", area_code: "103")
      b = described_class.new(code: "103-02", title: "A", area_code: "103")
      expect(a).not_to eq(b)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(section).to be_frozen
    end
  end
end
