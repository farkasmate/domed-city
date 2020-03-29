# frozen_string_literal: true

# This class represents itv.yaml

module Dome
  class Settings
    def self.[](key)
      init unless @itv_yaml

      @itv_yaml[key]
    end

    def self.find_project_root
      path = Dir.pwd.split('/')
      until path.empty?
        unless File.exist? File.join(path, 'itv.yaml')
          path.pop
          next
        end
        return File.realpath(File.join(path))
      end
      # TODO: Error class
      raise 'Cannot locate itv.yaml'
    end

    def self.init
      project_root = find_project_root
      @itv_yaml = YAML.load_file(File.join(project_root, 'itv.yaml'))
      @itv_yaml['project_root'] = project_root
    end

    private_class_method :find_project_root, :init
  end
end
