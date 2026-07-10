#!/usr/bin/env ruby
# frozen_string_literal: true

# Thin wrapper around Iev::Reconciler::Pipeline.
#
# Usage:
#   bundle exec ruby scripts/reconcile.rb [--output DIR]
#
# Inputs:
#   ../iev-data/termbase.yaml   — historical termbase (~2020, 22k concepts)
#   ../iev-data-latest/pages/   — live HTML mirror (17k pages)
#
# Output:
#   <output>/concepts/*.yaml    — V3 ManagedConcept files
#   <output>/report/            — change summary + CSV + retired/new lists

SCRIPT_DIR = File.expand_path(__dir__)
REPO_ROOT = File.expand_path("..", SCRIPT_DIR)

require "bundler/setup"
require "glossarist"
require "iev"
require "optparse"

options = {
  output: File.join(REPO_ROOT, "tmp", "reconciled"),
  termbase: File.expand_path("../iev-data/termbase.yaml", REPO_ROOT),
  pages: File.expand_path("../iev-data-latest/pages", REPO_ROOT),
}

OptionParser.new do |opts|
  opts.on("--output DIR") { |v| options[:output] = v }
  opts.on("--termbase PATH") { |v| options[:termbase] = v }
  opts.on("--pages DIR") { |v| options[:pages] = v }
end.parse!

Iev::Reconciler::Pipeline.new(
  termbase_path: options[:termbase],
  pages_dir: options[:pages],
  output_dir: options[:output],
).run
