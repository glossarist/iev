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
  autoload :Exporter, "iev/exporter"
  autoload :IevCode, "iev/iev_code"
  autoload :Iso639Code, "iev/iso_639_code"
  autoload :Profiler, "iev/profiler"
  autoload :RelatonDb, "iev/relaton_db"
  autoload :Scraper, "iev/scraper"
  autoload :Section, "iev/section"
  autoload :SourceParser, "iev/source_parser"
  autoload :SubjectArea, "iev/subject_area"
  autoload :SubjectAreas, "iev/subject_areas"
  autoload :SubjectAreaConcepts, "iev/subject_area_concepts"
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
  #   if code or language not found then nil.
  #
  def self.get(code, lang)
    DataSource.fetch_term_designation(code, lang)
  rescue DataSource::NotFoundError
    nil
  end

  # Fetch full concept data (all languages) for a given IEV code.
  #
  # @param [String] code IEV code, e.g. "103-01-02"
  # @return [Hash] concept data hash with all languages
  # @raise [DataSource::NotFoundError] if concept not found
  def self.fetch_concept(code)
    DataSource.fetch_concept(code)
  end

  # Fetch localized term data for a given IEV code and language.
  #
  # @param [String] code IEV code, e.g. "103-01-02"
  # @param [String] lang language code, e.g. "en" or "eng"
  # @return [Hash, nil] localized concept data or nil if not found
  # @raise [DataSource::NotFoundError] if concept not found
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

  # Return all IEV subject areas with their sections (from bundled data).
  # @return [Array<SubjectArea>]
  def self.subject_areas
    SubjectAreas.all
  end

  # Find a subject area by code.
  # @param code [String, Integer] e.g. "102"
  # @return [SubjectArea, nil]
  def self.find_subject_area(code)
    SubjectAreas.find_area(code)
  end

  # Find a section by its section code.
  # @param section_code [String] e.g. "102-01"
  # @return [Section, nil]
  def self.find_section(section_code)
    SubjectAreas.find_section(section_code)
  end

  # Return sections for a given area code.
  # @param code [String, Integer] e.g. "102"
  # @return [Array<Section>]
  def self.sections_for(code)
    SubjectAreas.sections_for(code)
  end

  # Return the parent subject area for a given section code.
  # @param section_code [String] e.g. "102-01"
  # @return [SubjectArea, nil]
  def self.area_for_section(section_code)
    SubjectAreas.area_for_section(section_code)
  end

  # Parse an IEV code into its structural components.
  # @param code [String] e.g. "103-01-02"
  # @return [IevCode, nil] nil if the code is blank
  def self.parse_code(code)
    IevCode.parse(code)
  end
end
