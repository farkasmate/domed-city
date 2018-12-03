# frozen_string_literal: true

module Dome
  class Settings
    include Dome::Level

    def parse
      raise('[*] itv.yaml does not exist') unless File.exist? itv_yaml_path

      load_yaml
    end

    def load_yaml
      @load_yaml ||= YAML.load_file(itv_yaml_path)
    end

    def itv_yaml_path
      case level
      when 'roles'
        '../../../../itv.yaml'
      when 'environment'
        '../../../itv.yaml'
      when 'ecosystem'
        '../../itv.yaml'
      when 'product'
        '../itv.yaml'
      when 'root'
        'itv.yaml'
        end
    end

    def project_root
      File.realpath(File.dirname(itv_yaml_path))
    end
  end
end
