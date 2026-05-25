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
    silence_output_streams { example.run }
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
    expect(source.origin.link).to eq("https://webstore.iec.ch/publication/6790")
    expect(source.origin.original).to eq('IEC 62302:2007, 3.2, modified – math element "stem:[L]"')
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
      "ITU-T Recommendation F.791 (11/2015)" => ["ITU-T Recommendation", "F.791 (11/2015)"],
      "ITU-T Recommendation F.791" => ["ITU-T Recommendation", "F.791"],
      "ITU-R Recommendation 592" => ["ITU-R Recommendation", "592"],
      "ITU-R RR" => ["ITU-R", "RR"],
    }.each do |input, (expected_source, expected_id)|
      expected_id ||= nil
      it "splits #{input.inspect} into source=#{expected_source.inspect} id=#{expected_id.inspect}" do
        source, id = parser.send(:split_ref, input)
        expect(source).to eq(expected_source)
        expect(id).to eq(expected_id)
      end
    end
  end
end
