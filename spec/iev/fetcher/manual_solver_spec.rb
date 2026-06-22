# frozen_string_literal: true

require "spec_helper"
require "stringio"

require "iev/fetcher"
require "iev/fetcher/manual_solver"

# Minimal fake of the Playwright browser/page surface that ManualSolver
# consumes. Real Ruby classes — not doubles (per project rule).
#
# Each call to #content returns the next state from the contents list, so
# a spec can model "challenge on first visit, real page on second visit
# after the user solved it." Mirrors how a real browser page would change
# state as the user interacts with it.
class FakeManualPage
  attr_reader :goto_url

  def initialize(contents)
    @contents = Array(contents)
    @goto_url = nil
    @content_index = 0
  end

  def goto(url)
    @goto_url = url
  end

  def content
    current = @contents[@content_index] || @contents.last
    @content_index += 1
    current
  end
end

class FakeManualBrowser
  attr_reader :pages, :closed

  def initialize(pages)
    @pages = Array(pages)
    @page_index = 0
    @closed = false
  end

  def new_page
    page = @pages[@page_index] || @pages.last
    @page_index += 1
    page
  end

  def close
    @closed = true
  end
end

RSpec.describe Iev::Fetcher::ManualSolver do
  let(:output) { StringIO.new }
  let(:valid_html) { "#{'x' * 20_000}<body>real page</body>" }
  let(:challenge_html) { "Confirm you are human" }

  def solver_with(pages:, input: StringIO.new("\n"))
    browser = FakeManualBrowser.new(pages)
    described_class.new(
      input: input,
      output: output,
      browser_factory: -> { browser },
    )
  end

  it "returns page HTML when no WAF challenge is detected" do
    page = FakeManualPage.new([valid_html])
    solver = solver_with(pages: page)

    expect(solver.fetch("https://example.test/iev")).to eq(valid_html)
  end

  it "prints instructions and waits for the user when WAF blocks" do
    page = FakeManualPage.new([challenge_html, valid_html])
    solver = solver_with(pages: page, input: StringIO.new("\n"))

    html = solver.fetch("https://example.test/iev")

    expect(html).to eq(valid_html)
    expect(output.string).to include("Solve it in the browser window")
  end

  it "returns nil when the user times out without pressing Enter" do
    # IO.pipe returns [read_end, write_end]; never writing means #gets blocks.
    read_end, _write_end = IO.pipe
    page = FakeManualPage.new([challenge_html, valid_html])
    solver = described_class.new(
      input: read_end,
      output: output,
      wait_timeout: 0.05,
      browser_factory: -> { FakeManualBrowser.new(page) },
    )

    html = solver.fetch("https://example.test/iev")
    expect(html).to be_nil
    expect(output.string).to include("Timed out")
  ensure
    read_end.close
  end

  it "returns nil when the page still shows a challenge after user input" do
    page = FakeManualPage.new([challenge_html, challenge_html])
    solver = solver_with(pages: page, input: StringIO.new("\n"))

    expect(solver.fetch("https://example.test/iev")).to be_nil
  end

  it "closes the browser on quit" do
    browser = FakeManualBrowser.new(FakeManualPage.new([valid_html]))
    solver = described_class.new(
      input: StringIO.new,
      output: output,
      browser_factory: -> { browser },
    )
    solver.fetch("https://example.test/iev")
    solver.quit

    expect(browser.closed).to be(true)
  end

  it "quit is safe to call multiple times" do
    browser = FakeManualBrowser.new(FakeManualPage.new([valid_html]))
    solver = described_class.new(
      input: StringIO.new,
      output: output,
      browser_factory: -> { browser },
    )

    expect { solver.quit.then { solver.quit } }.not_to raise_error
  end

  it "returns nil when the browser raises an error" do
    failing_browser = Class.new do
      def new_page = raise("boom")
      def close = nil
    end.new
    solver = described_class.new(
      input: StringIO.new,
      output: output,
      browser_factory: -> { failing_browser },
    )

    expect(solver.fetch("https://example.test/iev")).to be_nil
  end
end
