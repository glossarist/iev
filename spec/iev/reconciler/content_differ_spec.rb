# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Reconciler::ContentDiffer do
  let(:differ) { described_class.new }
  let(:date) { "2026-07-10" }

  def make_concept(code, status: "valid", localized: {})
    mc = Glossarist::ManagedConcept.of_yaml("id" => code, "data" => { "id" => code })
    mc.status = status
    mc.schema_version = "3"
    localized.each do |lang, data|
      cdata = Glossarist::ConceptData.new
      cdata.id = code
      cdata.language_code = lang
      cdata.entry_status = "valid"
      cdata.terms = [Glossarist::Designation::Expression.new(
        designation: data[:term], normative_status: "preferred"
      )]
      if data[:definition]
        cdata.definition = [Glossarist::DetailedDefinition.new(content: data[:definition])]
      end
      cdata.notes = Array(data[:notes]).map { |n| Glossarist::DetailedDefinition.new(content: n) }
      cdata.examples = Array(data[:examples]).map { |e| Glossarist::DetailedDefinition.new(content: e) }
      lc = Glossarist::LocalizedConcept.new
      lc.id = code
      lc.data = cdata
      mc.add_l10n(lc)
    end
    mc
  end

  it "returns empty ChangeSet for identical concepts" do
    old = make_concept("102-01-01", localized: { eng: { term: "equality", definition: "same" } })
    new = make_concept("102-01-01", localized: { eng: { term: "equality", definition: "same" } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs).to be_empty
  end

  it "detects definition change" do
    old = make_concept("102-01-01", localized: { eng: { term: "x", definition: "old text" } })
    new = make_concept("102-01-01", localized: { eng: { term: "x", definition: "new text" } })

    cs = differ.diff(old, new, detected_at: date)
    changes = cs.by_field(:definition)
    expect(changes.size).to eq(1)
    expect(changes.first.old_value).to eq("old text")
    expect(changes.first.new_value).to eq("new text")
  end

  it "detects designation change" do
    old = make_concept("102-01-01", localized: { eng: { term: "old term" } })
    new = make_concept("102-01-01", localized: { eng: { term: "new term" } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs.by_field(:designation).size).to eq(1)
  end

  it "detects status change" do
    old = make_concept("102-01-01", status: "valid", localized: { eng: { term: "x" } })
    new = make_concept("102-01-01", status: "retired", localized: { eng: { term: "x" } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs.by_field(:status).size).to eq(1)
  end

  it "detects language added" do
    old = make_concept("102-01-01", localized: { eng: { term: "x" } })
    new = make_concept("102-01-01", localized: { eng: { term: "x" }, fra: { term: "y" } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs.by_field(:language_added).size).to eq(1)
    expect(cs.by_field(:language_added).first.language).to eq("fra")
  end

  it "does not flag language removed (termbase languages preserved)" do
    old = make_concept("102-01-01", localized: { eng: { term: "x" }, deu: { term: "y" } })
    new = make_concept("102-01-01", localized: { eng: { term: "x" } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs.by_field(:language_removed)).to be_empty
  end

  it "normalizes HTML tags and whitespace before comparing" do
    old = make_concept("102-01-01", localized: { eng: { term: "x", definition: "hello world" } })
    new = make_concept("102-01-01", localized: { eng: { term: "x", definition: "<b>Hello</b>  World" } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs).to be_empty
  end

  it "detects notes change" do
    old = make_concept("102-01-01", localized: { eng: { term: "x", notes: ["old note"] } })
    new = make_concept("102-01-01", localized: { eng: { term: "x", notes: ["new note"] } })

    cs = differ.diff(old, new, detected_at: date)
    expect(cs.by_field(:notes).size).to eq(1)
  end
end
