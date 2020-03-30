# frozen_string_literal: true

require 'spec_helper'

require 'dome/level/roles'

describe Dome::RolesLevel do
  let(:level) { Dome::RolesLevel.new('terraform/hubsvc-dev/qa/roles') }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }
  before(:each) { allow(level).to receive(:validate) { true } }

  context '#initialize' do
    it 'parses valid account' do
      expect(level.account).to be == 'hubsvc-dev'
    end

    it 'parses valid environment' do
      expect(level.environment).to be == 'qa'
    end
  end
end
