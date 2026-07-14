#!/usr/bin/env ruby
# Identify cached HTML pages that PageParser cannot turn into a concept.
# Run: bundle exec ruby -Ilib scripts/find_unparseable.rb
require "iev"

store = Iev::Fetcher::PageStore.new
ok = 0
failed = []
store.each_concept(scope: Iev::Fetcher::Scope.all).each do |code, html|
  doc = Nokogiri::HTML(html)
  if Iev::Scraper::PageParser.new(doc, code).parse
    ok += 1
  else
    failed << code
  end
end

puts "Parsed OK:  #{ok}"
puts "Failed:     #{failed.size}"
puts
puts "First 20 failed codes:"
failed.take(20).each { |c| puts "  #{c}" }
