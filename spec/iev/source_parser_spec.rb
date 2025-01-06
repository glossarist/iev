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
    expected_parsed_sources = {
      "ref" => "IEC 62302:2007",
      "clause" => "3.2",
      "link" => "https://webstore.iec.ch/publication/6790",
      "relationship" => {
        "type" => "modified",
        "modification" => 'math element "stem:[L]"',
      },
      "original" => 'IEC 62302:2007, 3.2, modified – math element "stem:[L]"',
    }

    expect(subject.parsed_sources)
      .to be_an(Array)
      .and contain_exactly(expected_parsed_sources)
  end
end
