# frozen_string_literal: true

module IevHtmlPartialsHelpers
  def parse_term_attributes(str)
    Iev::TermAttrsParser.new(str)
  end

  def primary_designation(term, attribute = "n")
    data = { IEVREF: "485-22-07", LANGUAGE: "pl", TERM: term,
             TERMATTRIBUTE: attribute, DEFINITION: "x", STATUS: "Standard" }
    Iev::TermBuilder.new(data).build.data.terms.first
  end
end
