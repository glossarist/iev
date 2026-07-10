# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Reconciler::ConceptMerger do
  let(:merger) { described_class.new }
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
      lc = Glossarist::LocalizedConcept.new
      lc.id = code
      lc.data = cdata
      mc.add_l10n(lc)
    end
    mc
  end

  describe "merge both sources" do
    it "produces source: :both" do
      tb = make_concept("102-01-01", localized: { eng: { term: "x", definition: "old" } })
      live = make_concept("102-01-01", localized: { eng: { term: "x", definition: "new" } })

      rc = merger.merge(code: "102-01-01", termbase_concept: tb, live_concept: live, detected_at: date)
      expect(rc.source).to eq(:both)
    end

    it "uses live definition when it differs from termbase" do
      tb = make_concept("102-01-01", localized: { eng: { term: "x", definition: "old" } })
      live = make_concept("102-01-01", localized: { eng: { term: "x", definition: "new" } })

      rc = merger.merge(code: "102-01-01", termbase_concept: tb, live_concept: live, detected_at: date)
      eng_data = rc.managed_concept.localization("eng").data
      expect(eng_data.definition.first.content).to eq("new")
    end

    it "adds amended ConceptDate when content changed" do
      tb = make_concept("102-01-01", localized: { eng: { term: "x", definition: "old" } })
      live = make_concept("102-01-01", localized: { eng: { term: "x", definition: "new" } })

      rc = merger.merge(code: "102-01-01", termbase_concept: tb, live_concept: live, detected_at: date)
      amended_dates = rc.managed_concept.dates.select { |d| d.type == "amended" }
      expect(amended_dates).not_to be_empty
      expect(amended_dates.map { |d| d.date.to_s[0, 10] }).to include(date)
    end
  end

  describe "termbase only (retired)" do
    it "marks concept as retired" do
      tb = make_concept("102-01-01", status: "valid", localized: { eng: { term: "x" } })

      rc = merger.merge(code: "102-01-01", termbase_concept: tb, live_concept: nil, detected_at: date)
      expect(rc.source).to eq(:termbase_only)
      expect(rc.managed_concept.status).to eq("retired")
    end

    it "adds retired ConceptDate" do
      tb = make_concept("102-01-01", localized: { eng: { term: "x" } })

      rc = merger.merge(code: "102-01-01", termbase_concept: tb, live_concept: nil, detected_at: date)
      retired_dates = rc.managed_concept.dates.select { |d| d.type == "retired" }
      expect(retired_dates).not_to be_empty
    end

    it "preserves historical content" do
      tb = make_concept("102-01-01", localized: { eng: { term: "old term", definition: "old def" } })

      rc = merger.merge(code: "102-01-01", termbase_concept: tb, live_concept: nil, detected_at: date)
      eng_data = rc.managed_concept.localization("eng").data
      expect(eng_data.terms.first.designation).to eq("old term")
    end
  end

  describe "live only (new concept)" do
    it "produces source: :live_only" do
      live = make_concept("113-07-01", localized: { eng: { term: "new term" } })

      rc = merger.merge(code: "113-07-01", termbase_concept: nil, live_concept: live, detected_at: date)
      expect(rc.source).to eq(:live_only)
    end

    it "returns the live concept unchanged" do
      live = make_concept("113-07-01", localized: { eng: { term: "new term" } })

      rc = merger.merge(code: "113-07-01", termbase_concept: nil, live_concept: live, detected_at: date)
      expect(rc.managed_concept).to eq(live)
    end
  end
end
