module Dome
  class Settings
    def parse
      if File.exist? '../../../itv.yaml'
        @parsed_yaml ||= load_yaml
      else
        raise('[*] itv.yaml does not exist')
      end
    end

    def load_yaml
      YAML.load_file('../../../itv.yaml')
    end
  end
end
