# frozen_string_literal: true

require 'dome/level'

module Dome
  class EnvironmentLevel < Level
    def self.match(relative_path)
      %r{^terraform/\w*-\w*/\w*$}.match relative_path
    end
  end
end
