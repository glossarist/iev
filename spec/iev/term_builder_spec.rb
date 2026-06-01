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
      definition = "some definition<p>Note 1 to entry: first note<p>Note 2 to entry: second note"
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
      definition = "some definition<p><NOTE/>1 – first note<p><NOTE/>2 – second note"
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
end
