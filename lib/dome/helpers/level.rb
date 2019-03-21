# frozen_string_literal: true

module Dome
  module Level
    def level
      directories = Dir.pwd.split('/')


      if directories[-1] == 'terraform'
        'product'
      elsif directories[-2] == 'terraform'
        'ecosystem'
      elsif directories[-3] == 'terraform'
        'environment'
      elsif directories[-4] == 'terraform' and directories[-1] == 'roles'
        'roles'
      elsif directories[-5] == 'terraform' and directories[-2] == 'secrets' and directories[-1] == 'init'
        'secrets-init'
      elsif directories[-5] == 'terraform' and directories[-2] == 'secrets' and directories[-1] == 'config'
        'secrets-config'
      else
        puts "Invalid level: root".colorize(:red)
        'root'
      end
    end
  end
end
