# frozen_string_literal: true

require 'spec_helper'

describe Dome do
  let(:level) { 'environment' }
  let(:ecosystem) { 'dev' }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }
  before(:each) { allow_any_instance_of(Dome::Level).to receive(:level).and_return(level) }

  context 'environment validation against itv.yaml' do
    it 'identifies a valid environment' do
      dome = Dome::Level.create_level('terraform/deirdre-dev/qa')
      expect { dome.validate_environment }.not_to raise_error
    end

    it 'identifies an invalid environment' do
      dome = Dome::Level.create_level('terraform/deirdre-dev/foo')
      expect { dome.validate_environment }.to raise_error
    end
  end

  context 'account validation against itv.yaml' do
    it 'identifies a valid account' do
      dome = Dome::Level.create_level('terraform/hubsvc-prd/qa')
      expect { dome.validate_account }.not_to raise_error
    end

    it 'identifies an invalid account' do
      dome = Dome::Level.create_level('terraform/deirdre-blah/qa')
      expect { dome.validate_account }.to raise_error
    end
  end
end
