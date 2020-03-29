# frozen_string_literal: true

require 'dome/level'

module Dome
  class EnvironmentLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<account>\w*-\w*)/(?<environment>\w*)$}.freeze
  end
end
