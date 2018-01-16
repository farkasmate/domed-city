# frozen_string_literal: true

module Dome
  module Shell
    def execute_command(command, failure_message)
      puts "About to execute command: #{command.colorize(:yellow)}"
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
        while line = stdout.gets
          puts line
        end
        while line = stderr.gets
          puts line
        end
        exit_status = wait_thr.value
        Kernel.abort(failure_message) unless exit_status.success?
      end
    end
  end
end
