# frozen_string_literal: true

require 'dome/level'

module Dome
  class EcosystemLevel < Level
    def self.match(relative_path)
      %r{^terraform/\w*-\w*$}.match relative_path
    end
  end
end
