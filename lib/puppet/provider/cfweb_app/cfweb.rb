
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
        
        systemd_dir = '/etc/systemd/system'
        old_services = Dir.glob("#{systemd_dir}/app-*.service").
                            map { |v| File.basename(v, '.service') }
        old_services -= new_services
        old_services.each do |s|
            warning("Removing old service: #{s}")
            FileUtils.rm_f "#{systemd_dir}/#{s}.service"
        end
        
        if old_services.size
            systemctl(['daemon-reload'])
        end
    end
end
