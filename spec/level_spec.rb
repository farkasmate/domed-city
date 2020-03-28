# frozen_string_literal: true

require 'spec_helper'

describe Dome::Level do
  context '#find_plugin' do
    it 'matches product level in terraform directory' do
      expect(Dome::Level.find_plugin('terraform')).to equal(Dome::ProductLevel)
    end

    it 'matches ecosystem level in terraform/test-dev directory' do
      expect(Dome::Level.find_plugin('terraform/test-dev')).to equal(Dome::EcosystemLevel)
    end

    it 'matches environment level in terraform/test-prd/infraprd directory' do
      expect(Dome::Level.find_plugin('terraform/test-prd/infraprd')).to equal(Dome::EnvironmentLevel)
    end

    it 'matches roles level in terraform/test-dev/dev/roles directory' do
      expect(Dome::Level.find_plugin('terraform/test-dev/dev/roles')).to equal(Dome::RolesLevel)
    end
  end
end
