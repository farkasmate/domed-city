# frozen_string_literal: true

require 'logger'

module Dome
  class Logger < Logger
    # TODO: Configure logger
    @real_logger = Logger.new(STDERR)

    def self.info(message)
      @real_logger.info(message)
    end

    def self.debug(message)
      @real_logger.debug(message)
    end

    def self.warn(message)
      @real_logger.warn(message)
    end
  end
end
