require 'spec_helper'

describe Dome do
  let(:account_dir) { 'deirdre-dev' }
  let(:environment_dir) { 'qa' }
  let(:dome) { Dome::Environment.new([account_dir, environment_dir]) }

  context 'environment validation' do
    it 'identifies a valid environment' do
      account     = 'deirdre-dev'
      environment = 'sit'
      expect(dome.valid_environment?(account, environment)).to be_truthy
    end

    it 'identifies an invalid environment' do
      account     = 'deirdre-dev'
      environment = 'prd'
      expect(dome.valid_environment?(account, environment)).to be_falsey
    end
  end

  context 'account validation' do
    it 'identifies a valid account' do
      account = 'deirdre-prd'
      expect(dome.valid_account?(account)).to be_truthy
    end

    it 'identifies an invalid account' do
      account = 'deirdre-blah'
      expect(dome.valid_account?(account)).to be_falsey
    end
  end
end
