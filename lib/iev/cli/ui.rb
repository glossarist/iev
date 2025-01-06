# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module Cli
    # @todo
    #   Make it thread-safe.  Currently, calling UI methods from different
    #   threads may result with mangled output.  At first glance it seems like
    #   something is wrong with carriage returns, but more research is needed.
    module Ui
      module_function

      def debug(*args)
        Helper.cli_out(:debug, *args)
      end

      def warn(*args)
        Helper.cli_out(:warn, *args)
      end

      # Prints progress message which will be replaced on next call.
      def progress(message)
        return unless $IEV_PROGRESS

        print "#{Helper.clear_progress}#{message} "
      end

      # Prints generic message.
      def info(message)
        print "#{Helper.clear_progress}#{message}\n"
      end

      # Sets an UI tag which will be prepended to messages printed with
      # #debug and #warn.
      def set_ui_tag(str)
        Thread.current[:iev_ui_tag] = str
      end

      module Helper
        module_function

        def clear_progress
          $IEV_PROGRESS ? "\r#{' ' * 40}\r" : ""
        end

        def cli_out(level, *args)
          topic = args[0].is_a?(Symbol) ? args.shift : nil
          message = args.map(&:to_s).join(" ").chomp
          ui_tag = Thread.current[:iev_ui_tag]

          return unless should_out?(level, topic)

          print [
            clear_progress,
            ui_tag,
            ui_tag && ": ",
            message,
            "\n",
          ].join
        end

        def should_out?(level, topic)
          topic.nil? || level == :warn || $IEV_DEBUG[topic]
        end
      end
    end
  end
end
