# frozen_string_literal: true

require_relative "iev/version"
require "open-uri"
require "nokogiri"

require "benchmark"
require "creek"
require "unitsml"
require "plurimath"
require "glossarist"
require "relaton"
require "relaton_bib"
require "sequel"
require "thor"
require "yaml"

module Iev
  autoload :Cli, "iev/cli"
  autoload :Converter, "iev/converter"
  autoload :DataConversions, "iev/data_conversions"
  autoload :Db, "iev/db"
  autoload :DbCache, "iev/db_cache"
  autoload :DbWriter, "iev/db_writer"
  autoload :Iso639Code, "iev/iso_639_code"
  autoload :Profiler, "iev/profiler"
  autoload :RelatonDb, "iev/relaton_db"
  autoload :SourceParser, "iev/source_parser"
  autoload :SupersessionParser, "iev/supersession_parser"
  autoload :TermAttrsParser, "iev/term_attrs_parser"
  autoload :TermBuilder, "iev/term_builder"
  autoload :Utilities, "iev/utilities"

  #
  # Scrape Electropedia for term.
  #
  # @param [String] code for example "103-01-02"
  # @param [String] lang language code, for example "en"
  #
  # @return [String, nil] if found than term,
  # if code not found then empty string,
  #   if language not found then nil.
  #
  def self.get(code, lang)
    url = "http://www.electropedia.org/iev/iev.nsf/"\
          "display?openform&ievref=#{code}"
    doc = Nokogiri::HTML OpenURI.open_uri(url), nil, "UTF-8"
    xpath = "//table/tr/td/div/font[.=\"#{lang}\"]/../../"\
            "following-sibling::td[2]"
    a = doc&.at(xpath)&.children&.to_xml
    a&.sub(%r{<br/>.*$}, "")
      &.sub(/, &lt;.*$/, "")
      &.gsub(/<[^<>]*>/, "")&.strip
  end
end

require_relative "iev/cli"
