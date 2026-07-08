#!/usr/bin/env ruby
# frozen_string_literal: true

# Trigger Electropedia's interactive AWS WAF CAPTCHA, then dump DOM +
# screenshot. Used to design/tune waffle-punch selectors against the
# real Electropedia page (which may differ from CDD).
#
# Usage: bundle exec ruby scripts/probe_captcha.rb
# Outputs: tmp/captcha_probe_<timestamp>/ with frame HTML + screenshot

SCRIPT_DIR = File.expand_path(__dir__)
REPO_ROOT = File.expand_path("..", SCRIPT_DIR)
OUT_DIR = File.join(REPO_ROOT, "tmp", "captcha_probe_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
CONCEPT_URL = "https://www.electropedia.org/iev/iev.nsf/" \
              "display?openform&ievref=821-02-13"

require "playwright"
require "fileutils"

FileUtils.mkdir_p(OUT_DIR)
puts "Output: #{OUT_DIR}"

Playwright.create(playwright_cli_executable_path: ENV["PLAYWRIGHT_CLI_PATH"] || `which playwright`.strip) do |p|
  browser = p.chromium.launch(headless: false)
  context = browser.new_context(
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
               "AppleWebKit/537.36 (KHTML, like Gecko) " \
               "Chrome/131.0.0.0 Safari/537.36",
    viewport: { width: 1366, height: 768 },
  )
  page = context.new_page

  puts "Loading #{CONCEPT_URL}"
  page.goto(CONCEPT_URL, timeout: 30_000, waitUntil: "domcontentloaded")
  page.wait_for_timeout(2_000)

  html = page.content
  File.write(File.join(OUT_DIR, "01_initial.html"), html)
  puts "Wrote 01_initial.html (#{html.bytesize} bytes)"
  puts "  captcha.js marker: #{html.include?('captcha.js')}"
  puts "  amzn-captcha marker: #{html.include?('amzn-captcha')}"
  puts "  Confirm you are human: #{html.include?('Confirm you are human')}"

  # Iframe check
  frames = page.frames
  puts "  frames: #{frames.size}"
  frames.each_with_index do |frame, i|
    puts "    frame #{i}: url=#{frame.url}"
    begin
      fhtml = frame.content
      File.write(File.join(OUT_DIR, "frame_#{i}.html"), fhtml)
      if fhtml.include?("captcha") || fhtml.include?("amzn-captcha")
        puts "    frame #{i} contains captcha markers!"
      end
    rescue StandardError => e
      puts "    frame #{i} content failed: #{e.message}"
    end
  end

  page.screenshot(path: File.join(OUT_DIR, "01_initial.png"), fullPage: true)
  puts "Wrote 01_initial.png"

  # Look for the Begin button
  begin
    button = page.locator("#amzn-captcha-verify-button").first
    if button.count > 0
      puts "Found #amzn-captcha-verify-button — clicking"
      button.click(timeout: 5_000)
      page.wait_for_timeout(5_000)

      html2 = page.content
      File.write(File.join(OUT_DIR, "02_after_begin.html"), html2)
      page.screenshot(path: File.join(OUT_DIR, "02_after_begin.png"), fullPage: true)
      puts "Wrote 02_after_begin.html (#{html2.bytesize} bytes)"
      puts "  has canvas: #{html2.include?('<canvas')}"
      puts "  has .amzn-captcha-modal-title: #{html2.include?('amzn-captcha-modal-title')}"

      # Frame content after Begin
      frames = page.frames
      puts "  frames after begin: #{frames.size}"
      frames.each_with_index do |frame, i|
        begin
          fhtml = frame.content
          File.write(File.join(OUT_DIR, "frame_after_#{i}.html"), fhtml)
          if fhtml.include?("canvas") || fhtml.include?("amzn-captcha-modal")
            puts "    frame #{i} after-begin contains canvas/modal markers"
          end
        rescue StandardError => e
          puts "    frame #{i} content failed: #{e.message}"
        end
      end
    else
      puts "#amzn-captcha-verify-button not found"
    end
  rescue StandardError => e
    puts "Begin button interaction failed: #{e.message}"
  end

  puts "Sleeping 10s for inspection..."
  page.wait_for_timeout(10_000)
  browser.close
end