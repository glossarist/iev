# frozen_string_literal: true

module Iev
  # Batch-fetching pipeline for Electropedia pages.
  #
  # Fetcher mirrors Electropedia concept pages and section browse pages to a
  # local on-disk cache and re-parses them into Glossarist YAML. It reuses
  # Iev::Scraper::Browser and Iev::Scraper::PageParser for the actual page
  # work; this namespace adds orchestration, caching, and resumability.
  module Fetcher
    autoload :ConceptValidator, "iev/fetcher/concept_validator"
    autoload :ManualSolver,     "iev/fetcher/manual_solver"
    autoload :Mirror,           "iev/fetcher/mirror"
    autoload :PageStore,        "iev/fetcher/page_store"
    autoload :Scope,            "iev/fetcher/scope"
    autoload :SectionIndex,     "iev/fetcher/section_index"
    autoload :SequentialProbe,  "iev/fetcher/sequential_probe"
    autoload :Source,           "iev/fetcher/source"
    autoload :Waf,              "iev/fetcher/waf"
  end
end
