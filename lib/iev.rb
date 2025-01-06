# frozen_string_literal: true

require "iev/version"
require "iev/db"
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
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

module Iev
  #
  # Scrape Electropedia for term.
  #
  # @param [String] code for example "103-01-02"
  # @param [String] lang language code, for examle "en"
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

require "iev/cli"
