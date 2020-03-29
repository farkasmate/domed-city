# frozen_string_literal: true

module Dome
  class Secrets
    attr_reader :settings, :hiera

    def initialize(level)
      @level    = level
      @settings = Dome::Settings.new
      @hiera    = Dome::HieraLookup.new(@settings.project_root, @level.ecosystem, @level.environment)
    end

    def secret_env_vars
      return if dome_config.nil? || hiera_keys_config.nil?

      @hiera.secret_env_vars(hiera_keys_config)
    end

    def extract_certs
      return if dome_config.nil? || certs_config.nil?

      @hiera.extract_certs(certs_config)
    end

    def dome_config
      Logger.warn "No #{'dome'.colorize(:green)} key found in your itv.yaml." unless @settings.parse['dome']
      @settings.parse['dome']
    end

    def hiera_keys_config
      unless @settings.parse['dome']['hiera_keys']
        Logger.warn "No #{'hiera_keys'.colorize(:green)} sub-key under #{'dome'.colorize(:green)} key found "\
          'in your itv.yaml.'
      end
      @settings.parse['dome']['hiera_keys']
    end

    def certs_config
      unless @settings.parse['dome']['certs']
        Logger.warn "No #{'certs'.colorize(:green)} sub-key under #{'dome'.colorize(:green)} key found "\
          'in your itv.yaml.'
      end
      @settings.parse['dome']['certs']
    end
  end
end
