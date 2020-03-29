# frozen_string_literal: true

require 'spec_helper'

require 'dome/level/roles'

describe Dome::RolesLevel do
  let(:level) { Dome::RolesLevel.new('terraform/test-dev/qa/roles') }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow_any_instance_of(Dome::Settings).to receive(:find_project_root).and_return(project_root) }

  context '#initialize' do
    it 'parses valid account' do
      expect(level.account).to be == 'test-dev'
    end

    it 'parses valid environment' do
      expect(level.environment).to be == 'qa'
    end
  end
end
