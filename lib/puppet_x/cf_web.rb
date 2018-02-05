#
# Copyright 2016-2018 (c) Andrey Galkin
#


# Done this way due to some weird behavior in tests also ignoring $LOAD_PATH
begin
    require File.expand_path( '../cf_system', __FILE__ )
rescue LoadError
    require File.expand_path( '../../../../cfsystem/lib/puppet_x/cf_system', __FILE__ )
end


module PuppetX::CfWeb
    CFWEB_TYPES = [
        'global',
        'futoin',
    ]

    SLICE_PREFIX = 'system-'
    BASE_DIR = File.expand_path('../', __FILE__)

    #---
    require "#{BASE_DIR}/cf_web/provider_base"
    
    CFWEB_TYPES.each do |t|
        require "#{BASE_DIR}/cf_web/#{t}"
        require "#{BASE_DIR}/cf_web/#{t}/app"
    end
end
