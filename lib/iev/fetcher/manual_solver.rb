# frozen_string_literal: true

require "playwright" unless defined?(Playwright)

module Iev
  module Fetcher
    # Last-resort fallback in the archive → live → manual chain.
    #
    # When both Source::Archive and Browser::Session cannot retrieve a page
    # (archive gap + WAF challenge that headless Chrome can't clear), this
    # source opens a *visible* Chromium via Playwright and asks the user to
    # solve the WAF challenge by hand. Once the challenge is cleared, the
    # page HTML is returned like any other source.
    #
    # Playwright is loaded lazily on first #fetch so that simply having the
    # class autoloaded (e.g. in archive-only runs) does not require the
    # playwright CLI to be installed.
    class ManualSolver
      DEFAULT_WAIT_TIMEOUT = 300 # 5 minutes per challenge

      # @param input [IO] reads the user's "I solved it" signal.
      # @param output [IO] where instructions are printed.
      # @param wait_timeout [Numeric] seconds before giving up on a challenge.
      # @param browser_factory [#call] returns a Playwright browser instance.
      #   Injectable for specs; default launches real Chromium.
      def initialize(input: $stdin, output: $stderr,
                     wait_timeout: DEFAULT_WAIT_TIMEOUT,
                     browser_factory: method(:default_browser_factory))
        @input = input
        @output = output
        @wait_timeout = wait_timeout
        @browser_factory = browser_factory
        @playwright = nil
        @browser = nil
      end

      # @param url [String] the Electropedia URL to fetch.
      # @return [String, nil] the page HTML after the user clears WAF, or
      #   nil if the user abandons the challenge or the wait times out.
      def fetch(url)
        page = new_page
        page.goto(url)
        return page.content unless challenge?(page)

        prompt_user_to_solve(url)
        return nil unless await_user_confirmation

        html = page.content
        Waf.challenge?(html) ? nil : html
      rescue StandardError => e
        warn "IEV: ManualSolver failed for #{url}: #{e.message}"
        nil
      end

      # Releases Playwright and the browser. Safe to call multiple times.
      def quit
        @browser&.close
        @playwright&.stop
        @browser = nil
        @playwright = nil
      end

      private

      def challenge?(page)
        Waf.challenge?(page.content)
      end

      def prompt_user_to_solve(url)
        @output.puts "IEV: WAF challenge detected for #{url}."
        @output.puts "Solve it in the browser window, then press Enter here."
        @output.puts "(Waiting up to #{@wait_timeout.to_i}s.)"
      end

      def new_page
        browser.new_page
      end

      def browser
        @browser ||= @browser_factory.call
      end

      # Default factory: opens Chromium via Playwright. The Playwright
      # instance is stored on @playwright so #quit can stop it.
      def default_browser_factory
        @playwright = Playwright.create
        @playwright.playwright.chromium.launch(headless: false)
      end

      # Blocks until the user presses Enter or @wait_timeout elapses.
      # Returns true on Enter, false on timeout.
      # rubocop:disable Naming/PredicateMethod -- false positive; method has side effects
      def await_user_confirmation
        reader = Thread.new { @input.gets }
        if reader.join(@wait_timeout)
          reader.value
          true
        else
          reader.kill
          @output.puts "IEV: Timed out waiting for user input."
          false
        end
      end
      # rubocop:enable Naming/PredicateMethod
    end
  end
end
