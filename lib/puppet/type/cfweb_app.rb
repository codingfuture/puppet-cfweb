#
# Copyright 2016-2019 (c) Andrey Galkin
#

Puppet::Type.newtype(:cfweb_app) do
    desc "DO NOT USE DIRECTLY."
    
    autorequire(:cfsystem_flush_config) do
        ['begin']
    end
    autorequire(:cfsystem_memory_calc) do
        ['total']
    end
    autonotify(:cfsystem_flush_config) do
        ['commit']
    end
    
    ensurable do
        defaultvalues
        defaultto :absent
    end
    
    
    newparam(:name) do
        isnamevar
    end
    
    newproperty(:type) do
        isrequired
        validate do |value|
            value.is_a? String
        end
    end
    
    newproperty(:site) do
        isrequired
        validate do |value|
            value.is_a? String
        end
    end
    
    newproperty(:user) do
        isrequired
        validate do |value|
            value.is_a? String
        end
    end

    newproperty(:app_name) do
        isrequired
        validate do |value|
            value.is_a? String
        end
    end
    
    newproperty(:service_name) do
        validate do |value|
            value.is_a? String
        end
    end
    
    newproperty(:site_dir) do
        isrequired
        validate do |value|
            value.is_a? String
        end
    end
    
    newproperty(:cpu_weight) do
        isrequired
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end
    
    newproperty(:io_weight) do
        isrequired
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end
    
    newproperty(:misc) do
        isrequired
        validate do |value|
            value.is_a? Hash
        end
    end
end
