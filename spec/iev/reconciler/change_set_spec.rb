# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Reconciler::ChangeSet do
  let(:code) { "102-01-01" }
  let(:set) { described_class.new(code) }

  describe "#add and #each" do
    it "collects changes and iterates them" do
      c1 = Iev::Reconciler::Change.new(code: code, field: :definition, language: "eng")
      c2 = Iev::Reconciler::Change.new(code: code, field: :designation, language: "eng")

      set.add(c1).add(c2)

      expect(set.to_a).to contain_exactly(c1, c2)
    end
  end

  describe "#empty?" do
    it "is true with no changes" do
      expect(set).to be_empty
    end

    it "is false after adding a change" do
      set.add(Iev::Reconciler::Change.new(code: code, field: :status))
      expect(set).not_to be_empty
    end
  end

  describe "#by_field" do
    it "filters changes by field type" do
      set.add(Iev::Reconciler::Change.new(code: code, field: :definition, language: "eng"))
      set.add(Iev::Reconciler::Change.new(code: code, field: :designation, language: "eng"))
      set.add(Iev::Reconciler::Change.new(code: code, field: :definition, language: "fra"))

      expect(set.by_field(:definition).size).to eq(2)
      expect(set.by_field(:designation).size).to eq(1)
    end
  end

  describe "#by_language" do
    it "filters changes by language" do
      set.add(Iev::Reconciler::Change.new(code: code, field: :definition, language: "eng"))
      set.add(Iev::Reconciler::Change.new(code: code, field: :definition, language: "fra"))

      expect(set.by_language("eng").size).to eq(1)
      expect(set.by_language("fra").size).to eq(1)
    end
  end

  describe "#summary" do
    it "returns field => count hash" do
      set.add(Iev::Reconciler::Change.new(code: code, field: :definition, language: "eng"))
      set.add(Iev::Reconciler::Change.new(code: code, field: :definition, language: "fra"))
      set.add(Iev::Reconciler::Change.new(code: code, field: :status))

      expect(set.summary).to eq(definition: 2, status: 1)
    end
  end
end
