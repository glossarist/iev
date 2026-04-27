# frozen_string_literal: true

require "iev/version"
require "iev/config"
require "iev/data_source"

require "yaml"

# plurimath and unitsml both depend on mml, which has a transitive
# dependency version mismatch with lutaml-model in some environments.
# Load them when available; the DataSource APIs work without them.
begin
  require "plurimath"
rescue LoadError
  nil
end

begin
  require "unitsml"
rescue LoadError
  nil
end

module Iev
  autoload :Cli, "iev/cli"
  autoload :Config, "iev/config"
  autoload :Converter, "iev/converter"
  autoload :DataConversions, "iev/data_conversions"
  autoload :DataSource, "iev/data_source"
  autoload :DbWriter, "iev/db_writer"
  autoload :Iso639Code, "iev/iso_639_code"
  autoload :Profiler, "iev/profiler"
  autoload :RelatonDb, "iev/relaton_db"
  autoload :Scraper, "iev/scraper"
  autoload :SourceParser, "iev/source_parser"
  autoload :SupersessionParser, "iev/supersession_parser"
  autoload :TermAttrsParser, "iev/term_attrs_parser"
  autoload :TermBuilder, "iev/term_builder"
  autoload :Utilities, "iev/utilities"

  # Fetch term designation from IEV data.
  #
  # @param [String] code for example "103-01-02"
  # @param [String] lang language code, for example "en"
  #
  # @return [String, nil] if found then term,
  # if code not found then nil,
  #   if language not found then nil.
  #
  def self.get(code, lang)
    DataSource.fetch_term_designation(code, lang)
  end

  # Fetch full concept data (all languages) for a given IEV code.
  #
  # @param [String] code IEV code, e.g. "103-01-02"
  # @return [Hash, nil] concept data hash with all languages
  def self.fetch_concept(code)
    DataSource.fetch_concept(code)
  end

  # Fetch localized term data for a given IEV code and language.
  #
  # @param [String] code IEV code, e.g. "103-01-02"
  # @param [String] lang language code, e.g. "en" or "eng"
  # @return [Hash, nil] localized concept data
  def self.fetch_term(code, lang)
    DataSource.fetch_term(code, lang)
  end

  # Scrape concept data from Electropedia for a given IEV code.
  # Uses Ferrum (headless Chrome) to handle AWS WAF challenge.
  #
  # @param code [String] IEV code, e.g. "103-01-02"
  # @return [Hash, nil] concept data hash or nil if not found
  def self.scrape_concept(code)
    Scraper.new.fetch_concept(code)
  end
end
