# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module IEV
  module CLI
    def self.start(arguments)
      Signal.trap("INT") do
        UI.info "Signal SIGINT received, quitting!"
        Kernel.exit(1)
      end

      Signal.trap("TERM") do
        UI.info "Signal SIGTERM received, quitting!"
        Kernel.exit(1)
      end

      IEV::CLI::Command.start(arguments)
    end
  end
end
