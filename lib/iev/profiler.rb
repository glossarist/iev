# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  class Profiler
    attr_reader :bench, :dir, :prefix, :profile

    def self.measure(prefix = nil, &block)
      new(prefix).run(&block)
    end

    def initialize(prefix, dir: "profile")
      @prefix = prefix
      @dir = dir
    end

    def run(&block)
      profiler_enabled? ? run!(&block) : block.call
    end

    def run!(&block)
      retval = nil
      @profile = RubyProf.profile allow_exceptions: true do
        @bench = Benchmark.measure do
          retval = block.call
        end
      end
      retval
    ensure
      print_reports
    end

    def profiler_enabled?
      $IEV_PROFILE
    end

    private

    def print_reports
      FileUtils.mkdir_p(dir)
      print_benchmark("bench.txt")
      print_profile("flat.txt", RubyProf::FlatPrinter)
      print_profile("graph.html", RubyProf::GraphHtmlPrinter)
      print_profile("calls.html", RubyProf::CallStackPrinter)
    end

    def print_benchmark(suffix)
      return if bench.nil?

      contents = [Benchmark::CAPTION, bench.to_s].join("\n")
      File.write(report_file_name(suffix), contents)
    end

    def print_profile(suffix, printer)
      return if profile.nil?

      File.open(report_file_name(suffix), "w") do |file|
        printer.new(profile).print(file)
      end
    end

    def report_file_name(suffix)
      base_name = [prefix, suffix].compact.join("-")
      File.expand_path(base_name, dir)
    end
  end
end
