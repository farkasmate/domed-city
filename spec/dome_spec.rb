# frozen_string_literal: true

require 'spec_helper'

describe Dome do
  let(:account_dir) { 'deirdre-dev' }
  let(:environment_dir) { 'qa' }
  let(:level) {'environment'}
  let(:ecosystem) {'dev'}
  let(:itv_yaml_path) { 'spec/fixtures/itv.yaml' }

  before(:each) { allow_any_instance_of(Dome::Settings).to receive(:itv_yaml_path).and_return(itv_yaml_path) }
  before(:each) { allow_any_instance_of(Dome::Environment).to receive(:level).and_return(level) }

  let(:dome) { Dome::Environment.new([account_dir, environment_dir]) }

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
