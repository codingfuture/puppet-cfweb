
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
            self.send("check_#{params['type']}", params)
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end
    
    def self.on_config_change(newconf)
        debug('on_config_change')
        
        newconf.each do |k, conf|
            begin
                self.send("create_#{params['type']}", params)
            rescue => e
                warning(e)
                #warning(e.backtrace)
                err("Transition error in setup")
            end
        end
    end
end
