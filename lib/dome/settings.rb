module Dome
  class Settings
    def parse
      raise('[*] itv.yaml does not exist') unless File.exist? itv_yaml_path
      load_yaml
    end

    def load_yaml
      @parsed_yaml ||= YAML.load_file(itv_yaml_path)
    end

    def itv_yaml_path
      '../../../itv.yaml'
    end

    def project_root
      File.realpath(File.dirname(itv_yaml_path))
    end
  end
end
