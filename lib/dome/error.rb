# frozen_string_literal: true

module Dome
  class InvalidLevelError < StandardError
    def initialize(level)
      super "Invalid level: #{level}"
    end
  end
end
