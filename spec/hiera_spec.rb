# frozen_string_literal: true

require 'spec_helper'

describe Dome do
  let(:account_dir) { 'deirdre-dev' }
  let(:environment_dir) { 'qa' }
  let(:level) { Dome::Level.new([account_dir, environment_dir]) }
  let(:hiera) { Dome::HieraLookup.new(level) }
  let(:project_root) { File.realpath('spec/fixtures') }

  before(:each) { allow_any_instance_of(Dome::Settings).to receive(:find_project_root).and_return(project_root) }
  before(:each) { allow_any_instance_of(Dome::Level).to receive(:level).and_return('environment') }

  it 'outputs the correct message for a hiera lookup' do
    vars = { 'foo' => 'bar' }
    allow(hiera).to receive(:lookup).and_return('bar')

    expect(Dome::Logger).to receive(:info).with("[*] Setting \e[0;32;49mTF_VAR_foo\e[0m.")
    hiera.secret_env_vars(vars)
  end

  it 'outputs the correct error message for a failed hiera lookup' do
    vars = { 'foo' => 'bar' }
    allow(hiera).to receive(:lookup).and_return(nil)

    expect(Dome::Logger).to receive(:warn).with("\e[0;31;49m[!] Hiera lookup failed for 'bar', so TF_VAR_foo was not set.\e[0m")
    hiera.secret_env_vars(vars)
  end
end
