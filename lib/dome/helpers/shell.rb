# frozen_string_literal: true

module Dome
  module Shell
    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        }
      end
      return nil
    end
    def binary
      which 'terraform'
    end
    def execute_command(command, failure_message)
      puts "About to execute command: #{command.colorize(:yellow)}"
      Open3.popen3(command) do |_stdin, stdout, stderr, wait_thr|
        while line == stdout.gets
          puts line
        end
        while line == stderr.gets
          puts line
        end
        exit_status = wait_thr.value
        Kernel.abort(failure_message) unless exit_status.success?
      end
    end
  end
end
