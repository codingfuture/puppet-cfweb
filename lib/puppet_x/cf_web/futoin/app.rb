#
# Copyright 2016-2017 (c) Andrey Galkin
#


module PuppetX::CfWeb::Nodejs::App
    include PuppetX::CfWeb::Nodejs
    
    def check_futoin(conf)
        begin
            service_name = conf[:service_name]
            systemctl(['status', "#{service_name}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end
    
    def create_futoin(conf)
        cf_system = cf_system()
        site = conf[:site]
        type = conf[:type]
        user = conf[:user]
        site_dir = conf[:site_dir]
        service_name = conf[:service_name]

        run_dir = "/run/#{service_name}"

        # Service
        #---

        content_ini = {
            'Unit' => {
                'Description' => "CFWEB FutoIn #{site}",
            },
            'Service' => {
                'LimitNOFILE' => 'infinity',
                'WorkingDirectory' => "#{site_dir}",
                'Slice' => "#{PuppetX::CfWeb::SLICE_PREFIX}#{user}.slice",
                'ExecStart' => 'cid service master --adapt',
                'ExecReload' => '/bin/kill -USR1 $MAINPID',
            },
        }
        
        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => user,
            :content_ini => content_ini,
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
            :mem_limit => mem_limit,
        })
        
        if service_changed
            systemctl('restart', "#{service_name}.service")
        end
        
        return [service_name]
    end
end
