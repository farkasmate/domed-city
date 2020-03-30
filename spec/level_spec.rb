# frozen_string_literal: true

require 'spec_helper'

describe Dome::Level do
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }

  context '#create_level' do
    it 'creates product level in terraform directory' do
      expect(Dome::Level.create_level('terraform')).to be_instance_of(Dome::ProductLevel)
    end

    it 'creates ecosystem level in terraform/hubsvc-dev directory' do
      expect(Dome::Level.create_level('terraform/hubsvc-dev')).to be_instance_of(Dome::EcosystemLevel)
    end

    it 'creates environment level in terraform/hubsvc-prd/infraprd directory' do
      expect(Dome::Level.create_level('terraform/hubsvc-prd/infraprd')).to be_instance_of(Dome::EnvironmentLevel)
    end

    it 'creates roles level in terraform/hubsvc-dev/dev/roles directory' do
      expect(Dome::Level.create_level('terraform/hubsvc-dev/stg/roles')).to be_instance_of(Dome::RolesLevel)
    end
  end
end
