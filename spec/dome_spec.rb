require 'spec_helper'

describe Dome do
  let(:account_dir) { 'deirdre-dev' }
  let(:environment_dir) { 'qa' }
  let(:dome) { Dome::Environment.new([account_dir, environment_dir]) }

  let(:itv_yaml_path) { 'spec/fixtures/itv.yaml' }
  before(:each) { allow(dome.settings).to receive(:itv_yaml_path) { itv_yaml_path } }

  context 'environment validation' do
    it 'identifies a valid DEV environment in a DEV account' do
      account     = 'deirdre-dev'
      environment = 'foo'
      expect(dome.valid_environment?(account, environment)).to be_truthy
    end

    it 'identifies an invalid PRD environment for a DEV account' do
      account     = 'deirdre-dev'
      environment = 'prd'
      expect(dome.valid_environment?(account, environment)).to be_truthy
    end
  end

  context 'account validation' do
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
