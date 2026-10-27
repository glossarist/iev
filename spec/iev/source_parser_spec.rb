# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe Iev::SourceParser do
  subject do
    example = RSpec.current_example
    attributes_str = example.metadata[:string] || example.description
    described_class.new(attributes_str, "IEV")
  end

  around do |example|
    relaton_enabled = described_class.relaton_enabled
    described_class.relaton_enabled = false
    silence_output_streams { example.run }
  ensure
    described_class.relaton_enabled = relaton_enabled
  end

  example "MOD,ITU", string: "702-01-02 MOD,ITU-R Rec. 431 MOD" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("702-01-02 MOD", "ITU-R Rec. 431 MOD")
  end

  example "MOD. ITU", string: "161-06-01 MOD. ITU RR 139 MOD" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("161-06-01 MOD", "ITU RR 139 MOD")
  end

  example "XXX-XX-XX, ITU", string: "725-12-50, ITU RR 11" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("725-12-50", "ITU RR 11")
  end

  example "XXX-XX-XX, YYY-YY-YY", string: "705-02-01, 702-02-07" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("705-02-01", "702-02-07")
  end

  example "702-09-44 MOD, 723-07-47, voir 723-10-91" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("702-09-44 MOD", "723-07-47", "voir 723-10-91")
  end

  example "IEC 62303:2008, 3.1, modified and IEC 62302:2007, 3.2; IAEA 4" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("IEC 62303:2008, 3.1, modified",
                           "IEC 62302:2007, 3.2", "IAEA 4")
  end

  example "CEI 62303:2008, 3.1, modifiée et CEI 62302:2007, 3.2; AIEA 4" do
    expect(subject.src_split)
      .to be_an(Array)
      .and contain_exactly("CEI 62303:2008, 3.1, modifiée",
                           "CEI 62302:2007, 3.2", "AIEA 4")
  end

  example 'IEC 62302:2007, 3.2, modified – math element "<i>L</i>"' do
    source = subject.parsed_sources.first

    expect(source).to be_a(Glossarist::ConceptSource)
    expect(source.status).to eq("modified")
    expect(source.modification).to eq('math element "stem:[L]"')

    expect(source.origin).to be_a(Glossarist::Citation)
    expect(source.origin.ref).to be_a(Glossarist::Citation::Ref)
    expect(source.origin.ref.source).to eq("IEC")
    expect(source.origin.ref.id).to eq("62302:2007")
    expect(source.origin.locality).to be_a(Glossarist::Locality)
    expect(source.origin.locality.type).to eq("clause")
    expect(source.origin.locality.reference_from).to eq("3.2")
    expect(source.origin.link).to be_nil
    expect(source.origin.original)
      .to eq('IEC 62302:2007, 3.2, modified – math element "stem:[L]"')
  end

  describe "SOURCE cleanup from iev-data #22" do
    {
      "Voir 891-02-05" => ["IEV", nil, "891-02-05"],
      "voir 131-11-20" => ["IEV", nil, "131-11-20"],
      "voir 131-11-21" => ["IEV", nil, "131-11-21"],
      "voir 131-12-70" => ["IEV", nil, "131-12-70"],
      "voir 131-12-71" => ["IEV", nil, "131-12-71"],
      "voir 131-13-03" => ["IEV", nil, "131-13-03"],
      "voir 415-03-15" => ["IEV", nil, "415-03-15"],
      "voir 415-03-17" => ["IEV", nil, "415-03-17"],
      "voir 604-01-15" => ["IEV", nil, "604-01-15"],
      "voir 723-06-20" => ["IEV", nil, "723-06-20"],
      "voir 723-10-19" => ["IEV", nil, "723-10-19"],
      "voir 841-21-18" => ["IEV", nil, "841-21-18"],
      "voir 415‑03‑10" => ["IEV", nil, "415-03-10", "voir 415-03-10"],
      "Voir la CEI 50(845): Vocabulaire Électrotechnique International " \
      "de l'Éclairage." => ["IEC", "60050-845", nil],
      "voir CISPR 11" => ["IEC CISPR", "11", nil, "voir CISPR 11"],
      "voir la CEI 60050-121" => ["IEC", "60050-121", nil],
      "voir la CEI 60050-121, 151-12-05" => ["IEC", "60050-121", "151-12-05"],
      "voir la CEI 60050-131" => ["IEC", "60050-131", nil],
      "voir la CEI 60050-195" => ["IEC", "60050-195", nil],
      "voir la partie 121 de l'IEV" => ["IEC", "60050-121", nil],
      "voir la partie 726 de l'IEV" => ["IEC", "60050-726", nil],
    }.each do |input, (reference_source, reference_id, clause, original)|
      it "parses #{input.inspect}", string: input do
        source = subject.parsed_sources.fetch(0)

        expect(subject.parsed_sources.size).to eq(1)
        expect(subject.raw_str).to eq(input)
        expect(source.status).to eq("related")
        expect(source.origin.ref.source).to eq(reference_source)
        expect(source.origin.ref.id).to eq(reference_id)
        expect(source.origin.locality&.reference_from).to eq(clause)
        expect(source.modification).to be_nil
        expect(source.origin.link).to be_nil
        expect(source.origin.original).to eq(original || input)
      end
    end

    # These inputs need a representation decision before structured cleanup:
    # figures have no document target, prose qualifies the cited location, and
    # compound references include shorthand or symbol locators.
    [
      "Voir Tome V du Livre Rouge du CCITT,1960, pages 74 et 75.",
      "Voir la signification des symboles et les Notes 1, 2, 3 et 4 " \
      "à 845-04-05",
      "Voir la signification des symboles à 845-04-05",
      "voir fig. 1",
      "voir fig. 3.1",
      "voir fig. 3.12",
      "voir fig. 3.15",
      "voir fig. 3.2",
      "voir fig. 3.21",
      "voir fig. 3.25",
      "voir fig. 3.26",
      "voir fig. 3.27",
      "voir fig. 3.30",
      "voir fig. 3.31",
      "voir fig. 4",
      "voir fig. 4.1",
      "voir fig. 4.2",
      "voir fig. 4.3",
      "voir fig. 4.4",
      "voir fig. 4.5",
      "voir fig. 4.6",
      "voir fig. 4.7",
      "voir fig. 4.8",
      "voir fig. 4.9",
      "voir figure 466-6",
      "voir figure 466-7",
      "voir figure 466-8",
      "voir figure 466-9",
      "voir la CEI 60050-131, CEI 61293, CEI 60417, N°5031",
      "voir la Note à 845-01-33",
      "voir le chapitre 725",
      "voir les CEI 60050-101 et 121",
      "voir vitesse vectorielle du vent en 415-03-02",
    ].each do |input|
      it "preserves unresolved #{input.inspect}", string: input do
        expect(subject.raw_str).to eq(input)
        expect(subject.parsed_sources.map { |source| source.origin.original })
          .to eq([input])
        expect(subject.parsed_sources.first.status).to eq("related")
      end
    end
  end

  describe "#split_ref" do
    let(:parser) { described_class.new("IEC 1:2000, 1", "IEV") }

    {
      "IEC 62302:2007" => ["IEC", "62302:2007"],
      "IEC 60050-121" => ["IEC", "60050-121"],
      "IEC 60050-121:2003" => ["IEC", "60050-121:2003"],
      "ISO 1087-1:2000" => ["ISO", "1087-1:2000"],
      "ISO 9000" => ["ISO", "9000"],
      "ISO/IEC 2382:2015" => ["ISO/IEC", "2382:2015"],
      "ISO/IEC Guide 2" => ["ISO/IEC Guide", "2"],
      "ISO/IEC/IEEE 24765:2010" => ["ISO/IEC/IEEE", "24765:2010"],
      "ISO/TS 14812:2022" => ["ISO/TS", "14812:2022"],
      "ISO/TR 9593-4:1992" => ["ISO/TR", "9593-4:1992"],
      "IEC/IEEE 80005-1:2019" => ["IEC/IEEE", "80005-1:2019"],
      "IEC CISPR 16-1:2003" => ["IEC CISPR", "16-1:2003"],
      "IEC Guide 115" => ["IEC Guide", "115"],
      "IAEA 4" => ["IAEA", "4"],
      "IEV" => ["IEV", nil],
      "JCGM VIM" => ["JCGM", "VIM"],
      "ITU-T Recommendation F.791 (11/2015)" => ["ITU-T Recommendation",
                                                 "F.791 (11/2015)"],
      "ITU-T Recommendation F.791" => ["ITU-T Recommendation", "F.791"],
      "ITU-R Recommendation 592" => ["ITU-R Recommendation", "592"],
      "ITU-R RR" => ["ITU-R", "RR"],
    }.each do |input, (expected_source, expected_id)|
      expected_id ||= nil
      it "splits #{input.inspect} into source and id" do
        source, id = parser.send(:split_ref, input)
        expect(source).to eq(expected_source)
        expect(id).to eq(expected_id)
      end
    end
  end
end
