# frozen_string_literal: true

RSpec.describe Iev::TermBuilder do
  subject { described_class.new({}) }

  describe "#flesh_date" do
    context "when date is empty or nil" do
      it "returns empty date" do
        expect(subject.flesh_date("")).to eq("")
        expect(subject.flesh_date(nil)).to be_nil
      end
    end

    context "when month and day are missing" do
      it "defaults them to 01" do
        expect(subject.flesh_date("2022"))
          .to eq("2022-01-01T00:00:00+00:00")
      end
    end

    context "when only day is missing" do
      it "defaults day to 01" do
        expect(subject.flesh_date("2022-04"))
          .to eq("2022-04-01T00:00:00+00:00")
      end
    end

    context "when full date is given" do
      it "parses complete date" do
        expect(subject.flesh_date("2022-04-15"))
          .to eq("2022-04-15T00:00:00+00:00")
      end
    end
  end

  describe "#extract_classification" do
    # #188: Classification should be lowercased
    it "lowercases 'Preferred' to 'preferred'" do
      builder = described_class.new({ SYNONYM1STATUS: "Preferred" })
      expect(builder.extract_classification).to eq("preferred")
    end

    it "returns nil for empty string" do
      builder = described_class.new({ SYNONYM1STATUS: "" })
      expect(builder.extract_classification).to be_nil
    end

    it "returns nil when classification is missing" do
      builder = described_class.new({})
      expect(builder.extract_classification).to be_nil
    end
  end

  describe "#split_definition" do
    # #160, #161: Note/example extraction with numbering artifacts
    it "extracts notes from definition with 'Note N to entry:' pattern" do
      definition = "some definition<p>Note 1 to entry: first note<p>Note " \
                   "2 to entry: second note"
      builder = described_class.new({ IEVREF: "103-01-02",
                                      DEFINITION: definition })
      builder.split_definition
      notes = builder.extract_notes
      expect(notes.length).to eq(2)
    end

    it "extracts examples from definition with 'EXAMPLE' pattern" do
      definition = "some definition<p>EXAMPLE an example here"
      builder = described_class.new({ IEVREF: "103-01-02",
                                      DEFINITION: definition })
      builder.split_definition
      examples = builder.extract_examples
      expect(examples.length).to eq(1)
    end

    # #11: <NOTE/> pattern
    it "handles <NOTE/> pattern" do
      definition = "some definition<p><NOTE/>1 – first note<p><NOTE/>2 – " \
                   "second note"
      builder = described_class.new({ IEVREF: "103-01-02",
                                      DEFINITION: definition })
      builder.split_definition
      notes = builder.extract_notes
      expect(notes.length).to eq(2)
    end

    it "handles NOTE pattern" do
      definition = "some definition<p>NOTE 1 - a note<p>NOTE 2 - another note"
      builder = described_class.new({ IEVREF: "103-01-02",
                                      DEFINITION: definition })
      builder.split_definition
      notes = builder.extract_notes
      expect(notes.length).to eq(2)
    end
  end

  describe "#extract_domain" do
    it "returns section title when section exists" do
      # Area 103, Section 103-01 = "General concepts" (from bundled data)
      builder = described_class.new({ IEVREF: "103-01-02" })
      expect(builder.extract_domain).to eq("General concepts")
    end

    it "returns area title as fallback when section not found" do
      # Area 103 exists but section 103-99 does not
      builder = described_class.new({ IEVREF: "103-99-01" })
      expect(builder.extract_domain).to eq("Mathematics - Functions")
    end

    it "returns nil when term_id is nil" do
      builder = described_class.new({})
      expect(builder.extract_domain).to be_nil
    end

    it "returns nil for a completely unknown area" do
      builder = described_class.new({ IEVREF: "999-01-01" })
      expect(builder.extract_domain).to be_nil
    end

    it "returns nil gracefully on unexpected errors" do
      builder = described_class.new({ IEVREF: "103-01-02" })
      allow(Iev).to receive(:find_section).and_raise(NoMethodError, "boom")
      expect(builder.extract_domain).to be_nil
    end
  end

  # iev-data #128: angle-bracket text in a designation is usage info
  describe "designation usage info" do
    include IevHtmlPartialsHelpers

    it "moves an unclosed trailing <usage> out of the designation" do
      designation = primary_designation("badanie typu <ogniw paliwowych>")

      expect(designation.designation).to eq("badanie typu")
      expect(designation.usage_info).to eq("ogniw paliwowych")
    end

    it "handles the spurious closing tag printed in issue #128" do
      designation = primary_designation(
        "badanie typu <ogniw paliwowych></ogniw>",
      )

      expect(designation.designation).to eq("badanie typu")
      expect(designation.usage_info).to eq("ogniw paliwowych")
    end

    it "keeps grammar from TERMATTRIBUTE alongside term usage info" do
      designation = primary_designation("badanie typu <ogniw paliwowych>", "n")

      expect(designation.grammar_info.first.gender).to eq(["n"])
    end

    it "prefers TERMATTRIBUTE usage info when the term has none" do
      designation = primary_designation("ogniwo", "<paliwowe> n")

      expect(designation.designation).to eq("ogniwo")
      expect(designation.usage_info).to eq("paliwowe")
    end

    it "leaves plain designations and HTML markup untouched" do
      designation = primary_designation("H<sub>2</sub>O")

      expect(designation.usage_info).to be_nil
      expect(designation.designation).to eq("H~2~O")
    end
  end

  # iev-data #8: attribute cells that say "abbreviation" or "acronym"
  describe "abbreviation designations" do
    include IevHtmlPartialsHelpers

    def synonym_designation(term, attribute)
      described_class.new(
        { IEVREF: "103-01-02", LANGUAGE: "en", TERM: "quantity",
          SYNONYM1: term, SYNONYM1ATTRIBUTE: attribute, DEFINITION: "x",
          STATUS: "Standard" },
      ).build.data.terms.last
    end

    {
      "(abbreviation)" => "en",
      "(abréviation) f" => "fr",
      "Abkürzung" => "de",
      "（略語）" => "ja",
      "(abreviatura)" => "pt",
    }.each do |attribute, language|
      it "builds an Abbreviation for #{language} #{attribute.inspect}" do
        designation = synonym_designation("PDF", attribute)

        expect(designation).to be_a(Glossarist::Designation::Abbreviation)
        expect(designation.designation).to eq("PDF")
        expect(designation.acronym).to be_nil
      end
    end

    it "marks an explicit acronym as an acronym" do
      designation = synonym_designation("CWT", "(akronim)")

      expect(designation).to be_a(Glossarist::Designation::Abbreviation)
      expect(designation.acronym).to be(true)
    end

    it "keeps grammar next to the abbreviation marker" do
      designation = synonym_designation("CWT", "(abbreviation) m")

      expect(designation).to be_a(Glossarist::Designation::Abbreviation)
      expect(designation.grammar_info.first.gender).to eq(["m"])
    end

    it "builds an abbreviation from TERMATTRIBUTE too" do
      designation = primary_designation("PDF", "(abbreviation)")

      expect(designation).to be_a(Glossarist::Designation::Abbreviation)
    end

    it "keeps unmarked designations as plain expressions" do
      ["(of an amplifier)", "n", "Abklingkoeffizient", nil].each do |attr|
        designation = synonym_designation("PDF", attr)

        expect(designation.class).to eq(Glossarist::Designation::Expression)
      end
    end

    it "does not read a word that merely contains a marker" do
      designation = synonym_designation("x", "(abbreviationless)")

      expect(designation.class).to eq(Glossarist::Designation::Expression)
    end
  end
end
