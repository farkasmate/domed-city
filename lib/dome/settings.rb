# frozen_string_literal: true

module Dome
  class Settings
    include Dome::Level

    def parse
      raise("[*] #{itv_yaml_path} does not exist") unless File.exist? itv_yaml_path

      load_yaml
    end

    def load_yaml
      @load_yaml ||= YAML.load_file(itv_yaml_path)
    end

    def itv_yaml_path
      case level
      when /^secrets-/
        '../../../../../itv.yaml'
      when 'roles'
        '../../../../itv.yaml'
      when 'environment'
        '../../../itv.yaml'
      when 'ecosystem'
        '../../itv.yaml'
      when 'product'
        '../itv.yaml'
      else
        puts "Invalid level: #{level}".colorize(:red)
      end
    end

    def project_root
      File.realpath(File.dirname(itv_yaml_path))
    end
  end
end
