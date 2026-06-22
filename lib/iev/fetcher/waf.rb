# frozen_string_literal: true

module Iev
  module Fetcher
    # Stateless helper for detecting and retrying past AWS WAF challenge
    # pages. Consolidates the same pattern that lives privately inside
    # Iev::SubjectAreas so the Fetcher pipeline can share it without
    # touching SubjectAreas.
    module Waf
      MIN_PAGE_SIZE = 15_000
      RETRY_DELAY = 10
      MAX_RETRIES = 5

      class Error < StandardError
      end

      module_function

      # True if the response HTML looks like an AWS WAF interstitial.
      # nil is not a challenge — it is a soft fetch failure handled by the
      # caller (e.g. the fetcher returned nil after a browser error).
      def challenge?(html)
        return false unless html
        return true if html.length < MIN_PAGE_SIZE

        html.include?("Confirm you are human") ||
          html.include?("solve a puzzle") ||
          html.include?("security check before continuing")
      end

      # Yields the block and retries on a WAF challenge.
      #
      # @param retries [Integer] total attempts including the first.
      # @param delay [Integer, Numeric] base seconds to sleep between tries;
      #   actual wait is `delay * (attempt + 1)`.
      # @yieldreturn [String, nil] candidate HTML.
      # @return [String, nil] the first non-challenge HTML, or nil if the
      #   block returned nil and that was treated as a soft failure.
      # @raise [Error] if every attempt returns a challenge page.
      def fetch_with_retry(retries: MAX_RETRIES, delay: RETRY_DELAY)
        retries.times do |attempt|
          html = yield
          return html unless challenge?(html)

          raise_on_last_attempt(attempt, retries)
          wait_for_retry(attempt, delay)
        end
      end

      def raise_on_last_attempt(attempt, retries)
        return unless attempt >= retries - 1

        raise Error,
              "WAF challenge could not be cleared after #{retries} attempts"
      end

      def wait_for_retry(attempt, delay)
        wait = delay * (attempt + 1)
        warn "IEV: WAF challenge, retrying in #{wait}s (attempt #{attempt + 1})"
        sleep wait
      end
    end
  end
end
