module Dome
  module Shell
    def execute_command(command, failure_message)
      puts "About to execute command: #{command}"
      success = system command
      puts failure_message unless success
    end
  end
end
