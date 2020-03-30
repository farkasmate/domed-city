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
      expect { Dome::Level.create_level('terraform/hubsvc-dev/qa') }.not_to raise_error
    end

    it 'identifies an invalid environment' do
      expect { Dome::Level.create_level('terraform/hubsvc-dev/foo') }.to raise_error(Dome::InvalidEnvironmentError)
    end
  end

  context 'account validation against itv.yaml' do
    it 'identifies a valid account' do
      expect { Dome::Level.create_level('terraform/hubsvc-prd/qa') }.not_to raise_error
    end

    it 'identifies an invalid account' do
      expect { Dome::Level.create_level('terraform/hubsvc-blah/qa') }.to raise_error(Dome::InvalidAccountError)
    end
  end
end
