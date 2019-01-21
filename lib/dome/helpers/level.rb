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
      elsif directories[-4] == 'terraform'
        'roles'
      else
        'root'
      end
    end
  end
end
