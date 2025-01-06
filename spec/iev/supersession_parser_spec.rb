# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe Iev::SupersessionParser do
  # Parses :string metadata or example description.
  subject do
    example = RSpec.current_example
    attributes_str = example.metadata[:string] || example.description
    described_class.new(attributes_str)
  end

  example "731-03-24:1991-10-01" do
    expect(subject.supersessions).to eq([
                                          {
                                            "type" => "supersedes",
                                            "ref" => {
                                              "source" => "IEV",
                                              "id" => "731-03-24",
                                              "version" => "1991-10-01",
                                            },
                                          },
                                        ])
  end

  example "731-03-24:1991-10" do
    expect(subject.supersessions).to eq([
                                          {
                                            "type" => "supersedes",
                                            "ref" => {
                                              "source" => "IEV",
                                              "id" => "731-03-24",
                                              "version" => "1991-10",
                                            },
                                          },
                                        ])
  end

  example "731-03-24:1991" do
    expect(subject.supersessions).to eq([
                                          {
                                            "type" => "supersedes",
                                            "ref" => {
                                              "source" => "IEV",
                                              "id" => "731-03-24",
                                              "version" => "1991",
                                            },
                                          },
                                        ])
  end

  example "optional IEV prefix", string: "IEV 731-03-24:1991" do
    expect(subject.supersessions).to eq([
                                          {
                                            "type" => "supersedes",
                                            "ref" => {
                                              "source" => "IEV",
                                              "id" => "731-03-24",
                                              "version" => "1991",
                                            },
                                          },
                                        ])
  end

  example "spaces around colon", string: "731-03-24 : 1991" do
    expect(subject.supersessions).to eq([
                                          {
                                            "type" => "supersedes",
                                            "ref" => {
                                              "source" => "IEV",
                                              "id" => "731-03-24",
                                              "version" => "1991",
                                            },
                                          },
                                        ])
  end

  example "empty entry", string: " " do
    expect(subject.supersessions).to be(nil)
  end

  example "unparsable entry", string: "NOT IEV 731-03:1991" do
    expect(subject.supersessions).to be(nil)
  end
end
