# frozen_string_literal: true

require 'spec_helper'

require 'dome/level/ecosystem'

describe Dome::EcosystemLevel do
  let(:level) { Dome::EcosystemLevel.new('terraform/test-dev') }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }

  context '#initialize' do
    it 'parses valid account' do
      expect(level.account).to be == 'test-dev'
    end

    it 'parses nil environment' do
      expect(level.environment).to be(nil)
    end
  end
end
