# frozen_string_literal: true

require 'spec_helper'

describe Dome::Terraform do
  let(:assumed_role) { double('AssumedRole') }
  let(:credentials) { double('Credentials') }

  before(:each) { allow_any_instance_of(AwsAssumeRole::DefaultProvider).to receive(:resolve) { assumed_role } }
  before(:each) { allow(assumed_role).to receive(:credentials) { credentials } }
  before(:each) { allow(credentials).to receive(:access_key_id) { 'AKIAIOSFODNN7EXAMPLE' } }
  before(:each) { allow(credentials).to receive(:secret_access_key) { 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' } }
  before(:each) { allow(credentials).to receive(:session_token) { 'AQoEXAMPLEH4aoAH...ZaIv2BXIa2R4Olgk' } }

  context '#initialize' do
    it 'sets up AWS credentials' do
      Dome::Terraform.new('terraform/hubsvc-dev')
      expect(ENV['AWS_ACCESS_KEY_ID']).not_to be_nil
      expect(ENV['AWS_SECRET_ACCESS_KEY']).not_to be_nil
      expect(ENV['AWS_SESSION_TOKEN']).not_to be_nil
    end
  end
end
