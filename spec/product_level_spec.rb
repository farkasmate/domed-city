# frozen_string_literal: true

require 'spec_helper'

require 'dome/level/product'

describe Dome::ProductLevel do
  let(:level) { Dome::ProductLevel.new('terraform') }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dome::Settings).to receive(:find_project_root) { File.join(__dir__, 'fixtures') } }

  context '#initialize' do
    it 'parses <product>-prd account' do
      expect(level.account).to be == 'hubsvc-prd'
    end

    it 'parses nil environment' do
      expect(level.environment).to be(nil)
    end
  end
end
