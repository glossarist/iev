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
end
