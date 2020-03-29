# frozen_string_literal: true

require 'spec_helper'

describe Dome::Settings do
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow(Dir).to receive(:pwd) { File.join(__dir__, 'fixtures', 'sub', 'directory') } }

  context '#find_project_root' do
    it 'finds fixtures directory' do
      expect(Dome::Settings.send(:find_project_root)).to be == File.join(__dir__, 'fixtures')
    end
  end

  context '#[]' do
    it "['aws']['dev']['account_id'] returns account_id" do
      # FIXME: Should it return a String?
      expect(Dome::Settings['aws']['dev']['account_id']).to be == 832390933830 # rubocop:disable Style/NumericLiterals
    end

    it "['product'] returns product" do
      expect(Dome::Settings['product']).to be == 'hubsvc'
    end

    it "['project_root'] returns project_root" do
      expect(Dome::Settings['project_root']).to be == File.join(__dir__, 'fixtures')
    end
  end
end
