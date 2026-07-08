#!/usr/bin/env ruby
# frozen_string_literal: true

# Mirror Electropedia concepts using Ferrum (silent WAF) + waffle-punch
# (interactive CAPTCHA solver). Uses iev as a library; waffle-punch is
# loaded from a sibling checkout, NOT a gem dependency.
#
# Usage:
#   bundle exec ruby scripts/live_with_solver.rb [--section CODE]
#                                                [--limit N]
#                                                [--delay N]
#
# Prerequisites:
#   * iev must be in this checkout (you're running from its repo root)
#   * waffle-punch must be checked out at ../waffle-punch
#     (git clone git@github.com:riboseinc/waffle-punch.git)
#   * Playwright CLI must be installed (npm i -g playwright)
#   * GLM-4V API key at ~/.zai-api-key (or ZHIPUAI_API_KEY env var)
#
# The script defines SolverSession — a fetcher that tries Ferrum first
# (fast, silent-challenge bypass via UA / Sec-Ch-Ua-Platform / lang
# matching) and falls back to a Playwright + waffle-punch session when
# Ferrum hits the interactive CAPTCHA. The Playwright cookie jar
# persists for ~30min after a solve, so subsequent Ferrum fetches can
# ride that cleared cookie if we propagate it (TODO — for now each
# solver fetch is a fresh Playwright session).

SCRIPT_DIR = File.expand_path(__dir__)
REPO_ROOT = File.expand_path("..", SCRIPT_DIR)
WAFFLE_PUNCH_PATH = File.expand_path("../waffle-punch/lib", REPO_ROOT)

# Verify waffle-punch is checked out before we try to load it.
unless File.exist?(File.join(WAFFLE_PUNCH_PATH, "waffle_punch.rb"))
  warn "ERROR: waffle-punch not found at #{WAFFLE_PUNCH_PATH}"
  warn "Clone it first:"
  warn "  git clone git@github.com:riboseinc/waffle-punch.git \\"
  warn "    #{File.expand_path('../waffle-punch', REPO_ROOT)}"
  exit 1
end

# Load waffle-punch without making it a gem dependency.
$LOAD_PATH.unshift(WAFFLE_PUNCH_PATH)
require "waffle_punch"

require "iev"
require "iev/fetcher"
require "playwright" unless defined?(Playwright)

module IevLiveWithSolver
  # Combines the Ferrum fingerprint bypass (silent WAF) with waffle-punch
  # (interactive CAPTCHA). Plays well with Iev::Fetcher::Mirror's
  # fetcher contract: #fetch(url) -> String | nil, plus #restart and #quit.
  class SolverSession
    PAGE_TIMEOUT_MS = 30_000
    WAF_MAX_RETRIES = 5
    FETCHES_PER_PLAYWRIGHT_SESSION = 500
    SILENT_CHALLENGE_SETTLE_S = 10

    def initialize(solver: WafflePunch::CaptchaSolver.new,
                   ferrum_session: Iev::Scraper::Browser::Session.new)
      @solver = solver
      @ferrum = ferrum_session
      @fetches = 0
      @playwright = nil
      @pw_browser = nil
    end

    def fetch(url)
      html = @ferrum.fetch(url)
      @fetches += 1
      maybe_restart_ferrum

      return html unless challenge?(html)
      return html unless @solver.captcha_intro?(html.to_s)

      # Ferrum can't solve interactive CAPTCHAs; switch to Playwright.
      warn "IEV: interactive CAPTCHA detected; switching to waffle-punch"
      fetch_via_playwright(url)
    end

    def quit
      @ferrum&.quit
      @pw_browser&.close
      @playwright&.stop
      @pw_browser = nil
      @playwright = nil
    end

    def restart
      quit
      @ferrum = Iev::Scraper::Browser::Session.new
      @fetches = 0
      true
    rescue StandardError => e
      warn "IEV: SolverSession restart failed: #{e.message}"
      false
    end

    private

    def challenge?(html)
      Iev::Fetcher::Waf.challenge?(html.to_s)
    end

    def maybe_restart_ferrum
      return unless @fetches % FETCHES_PER_PLAYWRIGHT_SESSION == 0

      warn "IEV: Restarting Ferrum at #{@fetches} fetches " \
           "(#{FETCHES_PER_PLAYWRIGHT_SESSION}-page interval)."
      @ferrum.restart
    end

    def fetch_via_playwright(url)
      page = new_playwright_page
      attempts = 0
      while attempts < WAF_MAX_RETRIES
        page.goto(url, timeout: PAGE_TIMEOUT_MS, waitUntil: "domcontentloaded")
        html = wait_for_settle(page)

        return html unless challenge?(html)
        return html unless @solver.captcha_intro?(html)

        warn "IEV: solving CAPTCHA (attempt #{attempts + 1}/#{WAF_MAX_RETRIES})"
        begin
          cleared = @solver.solve(page)
          unless cleared
            warn "IEV: solver could not clear; giving up"
            return nil
          end
        rescue StandardError => e
          warn "IEV: solver error: #{e.message}"
          return nil
        end

        attempts += 1
      end
      nil
    ensure
      page&.close
    end

    # WAF serves a silent JS challenge first. Playwright (a real browser)
    # can clear it, but the JS takes a few seconds to execute and redirect.
    # Poll until the page settles into one of three terminal states:
    # real content, interactive CAPTCHA, or timeout.
    def wait_for_settle(page, timeout_s: SILENT_CHALLENGE_SETTLE_S)
      deadline = Time.now + timeout_s
      html = page.content
      while Time.now < deadline
        return html unless challenge?(html)
        return html if @solver.captcha_intro?(html)

        sleep 0.5
        html = page.content
      end
      html
    end

    def new_playwright_page
      playwright_context.new_page
    end

    def playwright_context
      return @pw_context if @pw_context

      @pw_context = playwright_browser.new_context(
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                   "AppleWebKit/537.36 (KHTML, like Gecko) " \
                   "Chrome/131.0.0.0 Safari/537.36",
        locale: "en-US",
        viewport: { width: 1366, height: 768 },
      )
    end

    def playwright_browser
      @pw_browser ||= playwright.chromium.launch(headless: true)
    end

    def playwright
      cli_path = ENV["PLAYWRIGHT_CLI_PATH"] || find_playwright_cli
      @playwright ||= Playwright.create(playwright_cli_executable_path: cli_path)
      @playwright.playwright
    end

    def find_playwright_cli
      path = `which playwright`.strip
      return path unless path.empty?

      raise "playwright CLI not found. Install with `npm install -g playwright` " \
            "or set PLAYWRIGHT_CLI_PATH env var."
    end
  end
end

# --- argument parsing (minimal, no OptionParser noise) ---

SECTION = ARGV.each_with_index.inject({}) do |acc, (arg, i)|
  if arg == "--section" && ARGV[i + 1]
    acc[:section] = ARGV[i + 1]
  elsif arg == "--limit" && ARGV[i + 1]
    acc[:limit] = ARGV[i + 1].to_i
  elsif arg == "--delay" && ARGV[i + 1]
    acc[:delay] = ARGV[i + 1].to_i
  elsif arg == "--jitter" && ARGV[i + 1]
    acc[:jitter] = ARGV[i + 1].to_f
  end
  acc
end

# --- run ---

cdx = Iev::Fetcher::CdxIndex.load(File.join(REPO_ROOT, "tmp", "cdx_display.json"))
warn "Loaded CDX index: #{cdx.total_codes} codes across #{cdx.sections.length} sections."

scope = if SECTION[:section]
          Iev::Fetcher::Scope.for_section(SECTION[:section])
        else
          Iev::Fetcher::Scope.from_cdx(cdx)
        end

source = IevLiveWithSolver::SolverSession.new
options = Iev::Fetcher::Mirror::Options.new(
  limit: SECTION[:limit],
  delay: SECTION[:delay] || Iev::Fetcher::Mirror::FETCH_DELAY,
  jitter: SECTION[:jitter] || Iev::Fetcher::Mirror::DEFAULT_JITTER,
  on_progress: lambda do |idx, total, code, status|
    marker = case status
             when :ok then "+"
             when :skipped then "."
             when :waf_blocked then "x"
             when :section_done then "\n"
             else " "
             end
    $stdout.write(marker)
    $stdout.flush
  end,
)

probe_factory = lambda do |section:, fetcher:, store:, validator:, refresh:|
  codes = cdx.codes_for_section(section.code)
  opts = Iev::Fetcher::ArchiveProbe::Options.new(store: store, refresh: refresh)
  Iev::Fetcher::ArchiveProbe.new(section.code,
                                 codes: codes,
                                 fetcher: fetcher,
                                 validator: validator,
                                 options: opts)
end

begin
  mirror = Iev::Fetcher::Mirror.new(
    scope: scope,
    fetcher: source,
    options: options,
    probe_factory: probe_factory,
  )
  mirror.run
  warn
  warn "Mirror complete: #{mirror.fetched} concepts fetched."
ensure
  source&.quit
end