# frozen_string_literal: true

require 'spec_helper'

require 'dome/level/environment'

describe Dome::EnvironmentLevel do
  let(:level) { Dome::EnvironmentLevel.new('terraform/hubsvc-prd/prd') }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }

  context '#initialize' do
    it 'parses valid account' do
      expect(level.account).to be == 'hubsvc-prd'
    end

    it 'parses valid environment' do
      expect(level.environment).to be == 'prd'
    end
  end
end
