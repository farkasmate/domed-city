# frozen_string_literal: true

require 'dome/level'

module Dome
  class EcosystemLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<account>\w*-\w*)$}.freeze
  end
end
