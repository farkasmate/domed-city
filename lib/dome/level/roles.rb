# frozen_string_literal: true

require 'dome/level'

module Dome
  class RolesLevel < Level
    def self.match(relative_path)
      %r{^terraform/\w*-\w*/\w*/roles$}.match relative_path
    end
  end
end
