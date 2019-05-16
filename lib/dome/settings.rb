# frozen_string_literal: true

# This class represents itv.yaml

module Dome
  class Settings
    attr_reader :project_root

    include Dome::Level

    def initialize(path = nil)
      if path
        raise "#{path} does not exist" unless File.exist? path

        @project_root = File.realpath(File.dirname(path))
      else
        @project_root = find_project_root
        path = File.join(@project_root, 'itv.yaml')
      end

      @itv_yaml ||= YAML.load_file(path)
    end

    def parse
      @itv_yaml
    end

    private

    def find_project_root
      path = Dir.pwd.split('/')
      until path.empty?
        unless File.exist? File.join(path, 'itv.yaml')
          path.pop
          next
        end
        return File.realpath(File.join(path))
      end
      raise 'Cannot locate itv.yaml'
    end
  end
end
