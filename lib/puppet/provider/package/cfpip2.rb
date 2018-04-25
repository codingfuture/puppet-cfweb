#
# Copyright 2018 (c) Andrey Galkin
#



# Copied from original Puppet Labs pip3.rb with minor changes

# Puppet package provider for Python's `pip2` package management frontend.
# <http://pip.pypa.io/>

require 'puppet/provider/package/pip'

Puppet::Type.type(:package).provide :cfpip2,
  :parent => :pip do

  desc "Python packages via `pip2`.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip2.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  has_feature :installable, :uninstallable, :upgradeable, :versionable, :install_options

  def self.cmd
    ["pip2"]
  end
end