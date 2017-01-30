#
# Copyright 2016-2017 (c) Andrey Galkin
#


require File.expand_path( '../../../../puppet_x/cf_web', __FILE__ )

Puppet::Type.type(:cfweb_app).provide(
    :cfweb,
    :parent => PuppetX::CfWeb::ProviderBase
) do
    desc "Provider for cfweb_app"
    
    mixin_dbtypes('app')
    
    commands :systemctl => '/bin/systemctl'
    
    def self.get_config_index
        'cf30web2_app'
    end

    def self.check_exists(params)
        debug('check_exists')
        begin
            self.send("check_#{params[:type]}", params)
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end
    
    def self.on_config_change(newconf)
        debug('on_config_change')
        
        new_services = []
        
        newconf.each do |k, conf|
            begin
                new_services += self.send("create_#{conf[:type]}", conf)
            rescue => e
                warning(e)
                #warning(e.backtrace)
                err("Transition error in setup")
            end
        end
        
        begin
            cf_system.cleanupSystemD('app-', new_services)
            cf_system.cleanupSystemD("#{PuppetX::CfWeb::SLICE_PREFIX}app_", new_services, 'slice')
        rescue => e
            warning(e)
            warning(e.backtrace)
            err("Transition error in setup")
        end
    end
end
