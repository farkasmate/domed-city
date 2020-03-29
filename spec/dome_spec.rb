# frozen_string_literal: true

require 'spec_helper'

describe Dome do
  let(:level) { 'environment' }
  let(:ecosystem) { 'dev' }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }
  before(:each) { allow_any_instance_of(Dome::Level).to receive(:level).and_return(level) }

  let(:dome) { Dome::Level.create_level('terraform/deirdre-dev/qa') }

  context 'environment validation against itv.yaml' do
    it 'identifies a valid environment' do
      environment = 'qa'
      expect(dome.valid_environment?(environment)).to be_truthy
    end

    it 'identifies an invalid environment' do
      environment = 'foo'
      expect(dome.valid_environment?(environment)).to be_falsey
    end
  end

  context 'account validation against itv.yaml' do
    it 'identifies a valid account' do
      account = 'hubsvc-prd'
      expect(dome.valid_account?(account)).to be_truthy
    end

    it 'identifies an invalid account' do
      account = 'deirdre-blah'
      expect(dome.valid_account?(account)).to be_falsey
    end
  end
end
