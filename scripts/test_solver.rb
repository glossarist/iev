#!/usr/bin/env ruby
# frozen_string_literal: true

# Focused end-to-end test of waffle-punch on a live Electropedia CAPTCHA.
# Opens Playwright, navigates to a CAPTCHA-triggering URL, runs the solver,
# and logs every step with timestamps. Captures screenshots before/after.
#
# Usage: bundle exec ruby scripts/test_solver.rb
# Output: tmp/solver_test_<timestamp>/ with logs + screenshots

SCRIPT_DIR = File.expand_path(__dir__)
REPO_ROOT = File.expand_path("..", SCRIPT_DIR)
WAFFLE_PUNCH_PATH = File.expand_path("../waffle-punch/lib", REPO_ROOT)
OUT_DIR = File.join(REPO_ROOT, "tmp", "solver_test_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
CONCEPT_URL = "https://www.electropedia.org/iev/iev.nsf/" \
              "display?openform&ievref=821-02-13"

unless File.exist?(File.join(WAFFLE_PUNCH_PATH, "waffle_punch.rb"))
  warn "ERROR: waffle-punch not found at #{WAFFLE_PUNCH_PATH}"
  exit 1
end

$LOAD_PATH.unshift(WAFFLE_PUNCH_PATH)
require "waffle_punch"
require "playwright"
require "fileutils"

FileUtils.mkdir_p(OUT_DIR)
LOG_PATH = File.join(OUT_DIR, "solver.log")
LOG = File.open(LOG_PATH, "w")

def log(msg)
  line = "[#{Time.now.strftime('%H:%M:%S.%3N')}] #{msg}"
  LOG.puts(line)
  LOG.flush
  warn line
end

log "Output dir: #{OUT_DIR}"
log "Loading waffle-punch + playwright"

Playwright.create(playwright_cli_executable_path: ENV["PLAYWRIGHT_CLI_PATH"] || `which playwright`.strip) do |p|
  log "Launching Chromium (headless)"
  browser = p.chromium.launch(headless: true)
  context = browser.new_context(
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
               "AppleWebKit/537.36 (KHTML, like Gecko) " \
               "Chrome/131.0.0.0 Safari/537.36",
    locale: "en-US",
    viewport: { width: 1366, height: 768 },
  )
  page = context.new_page

  log "Navigating to #{CONCEPT_URL}"
  page.goto(CONCEPT_URL, timeout: 30_000, waitUntil: "domcontentloaded")
  page.wait_for_timeout(2_000)

  html = page.content
  File.write(File.join(OUT_DIR, "01_intro.html"), html)
  page.screenshot(path: File.join(OUT_DIR, "01_intro.png"), fullPage: true)
  log "01 intro captured (#{html.bytesize} bytes)"

  solver = WafflePunch::CaptchaSolver.new(output: LOG)
  intro = solver.captcha_intro?(html)
  log "captcha_intro? => #{intro}"
  unless intro
    log "Page is not the interactive CAPTCHA intro — aborting"
    browser.close
    exit 1
  end

  log "Starting solver.solve(page, max_attempts: 3)"
  result = solver.solve(page, max_attempts: 3)
  log "solve returned: #{result}"

  html2 = page.content
  File.write(File.join(OUT_DIR, "02_after_solve.html"), html2)
  page.screenshot(path: File.join(OUT_DIR, "02_after_solve.png"), fullPage: true)
  log "02 after-solve captured (#{html2.bytesize} bytes)"

  if result
    title = page.evaluate("() => document.title || ''")
    log "Page title after solve: #{title.inspect}"
    log "SUCCESS — CAPTCHA cleared"
  else
    log "FAILURE — CAPTCHA not cleared"
  end

  browser.close
end

log "Done"
LOG.close
