# frozen_string_literal: true

module Dome
  module Helper
    module Shell
      def execute_command(command, failure_message)
        puts "[*] Running: #{command.colorize(:yellow)}"
        success = system command
        Kernel.abort(failure_message) unless success
      end
    end
  end
end
