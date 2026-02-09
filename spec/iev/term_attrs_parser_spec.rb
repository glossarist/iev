# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

RSpec.describe Iev::TermAttrsParser do
  # Parses :string metadata or example description.
  subject do
    example = RSpec.current_example
    attributes_str = example.metadata[:string] || example.description
    described_class.new(attributes_str)
  end

  describe "gender" do
    example "f" do
      expect(subject.gender).to eq("f")
    end

    example "m" do
      expect(subject.gender).to eq("m")
    end

    example "n" do
      expect(subject.gender).to eq("n")
    end

    it "works for empty strings", string: "" do
      expect(subject.gender).to be(nil)
    end

    it "works for strings which do not specify gender", string: "a whatever" do
      expect(subject.gender).to be(nil)
    end

    it "allows comma as a separator", string: "m, whatever" do
      expect(subject.gender).to eq("m")
    end

    it "is not fooled with longer sentences (begin/end of word)",
       string: "noun" do
      expect(subject.gender).to be(nil)
    end

    it "cannot be placed inside brackets", string: "(m)" do
      expect(subject.gender).to eq("m")
    end
  end

  describe "plurality" do
    example "pl" do
      expect(subject.plurality).to eq("plural")
    end

    example "f pl" do
      expect(subject.plurality).to eq("plural")
    end
    example "m pl" do
      expect(subject.plurality).to eq("plural")
    end
    example "n pl" do
      expect(subject.plurality).to eq("plural")
    end

    it "works for empty strings", string: "" do
      expect(subject.plurality).to be(nil)
    end

    it "works for strings which do not specify plurality",
       string: "a whatever" do
      expect(subject.plurality).to be(nil)
    end

    it "allows comma as a separator", string: "m,pl" do
      expect(subject.plurality).to eq("plural")
    end

    it "is not fooled with longer sentences (begin/end of word)",
       string: "what a plapl" do
      expect(subject.plurality).to be(nil)
    end

    it "always sets plurality if gender is specified", string: "f" do
      expect(subject.plurality).to eq("singular")
    end

    it "always sets plurality if gender is specified", string: "m" do
      expect(subject.plurality).to eq("singular")
    end

    it "always sets plurality if gender is specified", string: "n" do
      expect(subject.plurality).to eq("singular")
    end

    it "cannot be placed inside brackets", string: "(pl)" do
      expect(subject.plurality).to eq("plural")
    end
  end

  describe "part of speech" do
    example "adj" do
      expect(subject.part_of_speech).to eq("adj")
    end

    example "noun" do
      expect(subject.part_of_speech).to eq("noun")
    end

    example "verb" do
      expect(subject.part_of_speech).to eq("verb")
    end

    example "名詞" do
      expect(subject.part_of_speech).to eq("noun")
    end

    example "動詞" do
      expect(subject.part_of_speech).to eq("verb")
    end

    example "形容詞" do
      expect(subject.part_of_speech).to eq("adj")
    end

    example "형용사" do
      expect(subject.part_of_speech).to eq("adj")
    end

    example "Adjektiv" do
      expect(subject.part_of_speech).to eq("adj")
    end

    it "works for empty strings", string: "" do
      expect(subject.part_of_speech).to be(nil)
    end

    it "works for strings which do not specify p.o.s.", string: "a whatever" do
      expect(subject.part_of_speech).to be(nil)
    end

    it "allows comma as a separator", string: "adj, whatever" do
      expect(subject.part_of_speech).to eq("adj")
    end

    it "is not fooled with longer sentences (begin/end of word)",
       string: "adjunction radj" do
      expect(subject.part_of_speech).to be(nil)
    end
  end

  describe "usage info" do
    it "a string <info>" do
      expect(subject.usage_info).to eq("info")
    end

    it "<only info>" do
      expect(subject.usage_info).to eq("only info")
    end

    it "<  info with extra spaces\t>" do
      expect(subject.usage_info).to eq("info with extra spaces")
    end

    it "works for empty strings", string: "" do
      expect(subject.usage_info).to be(nil)
    end

    it "works for strings which do not specify usage info",
       string: "a whatever" do
      expect(subject.usage_info).to be(nil)
    end

    it "supports full-width signs", string: "a string \uFF1Cinfo\uFF1E" do
      expect(subject.usage_info).to eq("info")
    end

    it "disallows mixing regular and full-width signs",
       string: "a string \uFF1Cinfo>" do
      expect(subject.usage_info).to be(nil)
    end
  end

  describe "geographical area" do
    example "US" do
      expect(subject.geographical_area).to eq("US")
    end

    example "DE" do
      expect(subject.geographical_area).to eq("DE")
    end

    it "requires capital letters", string: "us" do
      expect(subject.geographical_area).to be(nil)
    end

    it "works for empty strings", string: "" do
      expect(subject.geographical_area).to be(nil)
    end

    it "works for strings which do not specify area",
       string: "a whatever" do
      expect(subject.geographical_area).to be(nil)
    end

    it "is not fooled with longer words",
       string: "THUS" do
      expect(subject.geographical_area).to be(nil)
    end
  end

  describe "prefix" do
    example "Präfix" do
      expect(subject.prefix).to be(true)
    end

    example "prefix" do
      expect(subject.prefix).to be(true)
    end

    example "préfixe" do
      expect(subject.prefix).to be(true)
    end

    example "接尾語" do
      expect(subject.prefix).to be(true)
    end

    example "접두사" do
      expect(subject.prefix).to be(true)
    end

    example "przedrostek" do
      expect(subject.prefix).to be(true)
    end

    example "prefixo" do
      expect(subject.prefix).to be(true)
    end

    example "词头" do
      expect(subject.prefix).to be(true)
    end

    it "works for empty strings", string: "" do
      expect(subject.prefix).to be(nil)
    end

    it "works for strings which do not specify prefix",
       string: "a whatever" do
      expect(subject.prefix).to be(nil)
    end

    it "is not fooled with longer words",
       string: "prefixed" do
      expect(subject.prefix).to be(nil)
    end
  end
end
