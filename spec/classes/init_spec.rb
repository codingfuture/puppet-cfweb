require 'spec_helper'
describe 'cfweb' do
  context 'with default values for all parameters' do
    it { should contain_class('cfweb') }
  end
end
