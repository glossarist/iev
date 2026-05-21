# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::SubjectArea do
  let(:sections) do
    [
      Iev::Section.new(code: "103-01", title: "General functions",
                       area_code: "103"),
      Iev::Section.new(code: "103-02", title: "Special functions",
                       area_code: "103"),
    ]
  end

  subject(:area) do
    described_class.new(code: "103", title: "Mathematics - Functions",
                        sections: sections)
  end

  it "exposes code" do
    expect(area.code).to eq("103")
  end

  it "exposes title" do
    expect(area.title).to eq("Mathematics - Functions")
  end

  it "exposes sections" do
    expect(area.sections).to eq(sections)
  end

  it "returns URI" do
    expect(area.uri).to eq("area-103")
  end

  describe "#section" do
    it "finds section by code" do
      found = area.section("103-01")
      expect(found).to be_a(Iev::Section)
      expect(found.title).to eq("General functions")
    end

    it "coerces code to string" do
      expect(area.section(103)).to be_nil
    end

    it "returns nil for unknown section" do
      expect(area.section("999-99")).to be_nil
    end
  end

  describe "#to_h" do
    it "round-trips to hash" do
      h = area.to_h
      expect(h["code"]).to eq("103")
      expect(h["title"]).to eq("Mathematics - Functions")
      expect(h["sections"].length).to eq(2)
      expect(h["sections"][0]).to eq({ "code" => "103-01",
                                       "title" => "General functions" })
    end
  end

  describe "empty sections" do
    subject(:area) { described_class.new(code: "999", title: "Empty") }

    it "has empty sections array" do
      expect(area.sections).to eq([])
    end
  end

  describe "equality" do
    it "is equal when codes match" do
      a = described_class.new(code: "103", title: "A")
      b = described_class.new(code: "103", title: "B")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "is not equal when codes differ" do
      a = described_class.new(code: "103", title: "A")
      b = described_class.new(code: "102", title: "A")
      expect(a).not_to eq(b)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(area).to be_frozen
    end
  end
end
