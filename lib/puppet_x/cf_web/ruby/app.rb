
module PuppetX::CfWeb::Ruby::App
    include PuppetX::CfWeb::Ruby
    
    def check_ruby(conf)
        begin
            service_name = conf[:service_name]
            systemctl(['status', "#{service_name}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end
    
    def create_ruby(conf)
        cf_system = cf_system()
        site = conf[:site]
        type = conf[:type]
        user = conf[:user]
        site_dir = conf[:site_dir]
        service_name = conf[:service_name]

        run_dir = "/run/#{service_name}"
        
        misc = conf[:misc]
        rvm_dir = misc['rvm_dir']
        version = misc['version']
        instances = misc['instances']
        entry_point = misc['entry_point']
        sock_base = misc['sock_base']
        tune = misc['tune']
        
        # Service
        #---
        mem_limit_global = cf_system.getMemory(service_name)
        mem_limit = (mem_limit_global / instances).to_i
        mem_fixed = tune.fetch('mem_fixed', 32).to_i
        mem_per_conn_kb = tune.fetch('mem_per_conn_kb', 2048).to_i
        max_conn = (mem_limit - mem_fixed) * 1024 / mem_per_conn_kb
        
        if max_conn < 1
            fail("Not enough memory for #{site} #{type}")
        end
        
        saveMaxConn(site, type, max_conn * instances)
        
        
        ruby_env = tune.fetch('ruby_env', 'production')
        services = []
        
        content_ini = {
            'Unit' => {
                'Description' => "CFWEB Ruby #{site}",
            },
            'Service' => {
                'LimitNOFILE' => 'infinity',
                'ExecStart' => [
                        "#{rvm_dir}/bin/rvm #{version} do puma",
                        "--bind unix://#{sock_base}",
                        "-e #{ruby_env}",
                        "-w #{instances}",
                        "-t #{max_conn}:#{max_conn}",
                        '--preload',
                ].join(' '),
                'ExecReload' => '/bin/kill -s USR2 $MAINPID',
                'WorkingDirectory' => "#{site_dir}/current",
                'Slice' => "#{user}.slice",
            },
        }
        
        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => user,
            :content_ini => content_ini,
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
            :mem_limit => mem_limit_global,
        })
        
        if service_changed
            systemctl('restart', "#{service_name}.service")
        end
        
        services << service_name
        
        return services
    end
end
