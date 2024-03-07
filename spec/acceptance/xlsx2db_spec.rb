# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe "IEV" do
  let(:sample_xlsx_file) { fixture_path("sample-file.xlsx") }

  describe "xlsx2db" do
    it "imports XLSX document to database" do
      Dir.mktmpdir("iev-test") do |dir|
        dbfile = "#{dir}/test.sqlite3"
        command = %W(xlsx2db #{sample_xlsx_file} -o #{dbfile})
        silence_output_streams { IEV::CLI.start(command) }

        expect(dbfile).to satisfy { |p| File.file? p }

        db = SQLite3::Database.new(dbfile)

        sql = <<~SQL
          select count(*)
          from concepts
          where language = 'en'
        SQL

        expect(db.execute(sql).first.first).to eq(2)

        sql = <<~SQL
          select term
          from concepts
          where language = 'en' and ievref = '103-01-01'
        SQL

        expect(db.execute(sql).first.first).to eq("function")
      end
    end
  end
end
