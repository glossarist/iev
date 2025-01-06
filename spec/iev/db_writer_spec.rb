# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe Iev::DbWriter do
  let(:instance) { described_class.new(db) }
  let(:db) { Sequel.sqlite }
  let(:sample_file) { fixture_path("sample-file.xlsx") }

  describe "#import_spreadsheet" do
    subject { instance.method(:import_spreadsheet) }

    it "creates concepts table" do
      silence_output_streams { subject.call(sample_file) }
      expect(db.table_exists?(:concepts)).to be(true)
    end

    it "fills concepts table with data" do
      silence_output_streams { subject.call(sample_file) }

      eng_row = db[:concepts].where(IEVREF: "103-01-01", LANGUAGE: "en").first
      kor_row = db[:concepts].where(IEVREF: "103-01-01", LANGUAGE: "ko").first

      expect(eng_row).not_to be(nil)
      expect(kor_row).not_to be(nil)

      expect(eng_row[:TERM]).to eq("function")
      expect(eng_row[:DEFINITION]).to start_with("See")
      expect(kor_row[:TERM]).to eq("함수")
      expect(kor_row[:SOURCE]).not_to be(nil)
    end
  end
end
