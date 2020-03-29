# frozen_string_literal: true

require 'spec_helper'

describe Dome do
  let(:level) { Dome::Level.create_level('terraform/deirdre-dev/qa') }
  let(:secrets) { Dome::Secrets.new(level) }

  # to prevent a validation error
  let(:project_root) { File.realpath('spec/fixtures') }
  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }
  before(:each) { allow_any_instance_of(Dome::Level).to receive(:level).and_return('environment') }

  context 'if config is missing from itv.yaml' do
    context 'outputs a debug message' do
      it 'when missing the parent key dome' do
        allow(Dome::Settings).to receive(:[]).and_return(nil)

        expect(Dome::Logger).to receive(:warn)
        secrets.dome_config
      end

      it 'when missing the sub-key hiera_keys' do
        data = { 'dome' => { 'foo' => 'bar' } }
        allow(Dome::Settings).to receive(:[]).and_return(data)

        expect(Dome::Logger).to receive(:warn)
        secrets.hiera_keys_config
      end

      it 'when missing the sub-key certs' do
        data = { 'dome' => { 'foo' => 'bar' } }
        allow(Dome::Settings).to receive(:[]).and_return(data)

        expect(Dome::Logger).to receive(:warn)
        secrets.certs_config
      end
    end

    it 'does not set secret environment variables' do
      allow(Dome::Settings).to receive(:[]).and_return(nil)
      expect(secrets.hiera).not_to receive(:secret_env_vars)
      secrets.secret_env_vars
    end

    it 'does not extract certificates' do
      allow(Dome::Settings).to receive(:[]).and_return({})
      expect(secrets.hiera).not_to receive(:extract_certs)
      secrets.extract_certs
    end
  end

  context 'with valid config' do
    it 'sets secret environment variables' do
      dome = { 'hiera_keys' => { 'artifactory_password' => 'artifactory::root-readonly::password' } }

      allow(Dome::Settings).to receive(:[]).with('product').and_return(nil)
      allow(Dome::Settings).to receive(:[]).with('aws').and_return(nil)
      allow(Dome::Settings).to receive(:[]).with('project_root').and_return(nil)
      allow(Dome::Settings).to receive(:[]).with('dome').and_return(dome)

      expect(secrets.hiera).to receive(:secret_env_vars)
      secrets.secret_env_vars
    end

    it 'extracts certificates' do
      dome = { 'certs' => { 'id_rsa' => 'aws::ssh_privkey_content' } }
      allow(Dome::Settings).to receive(:[]).and_return(dome)
      expect(secrets.hiera).to receive(:extract_certs)
      secrets.extract_certs
    end
  end
end
