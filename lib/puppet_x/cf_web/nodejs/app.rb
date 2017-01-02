#
# Copyright 2016-2017 (c) Andrey Galkin
#


module PuppetX::CfWeb::Nodejs::App
    include PuppetX::CfWeb::Nodejs
    
    def check_nodejs(conf)
        begin
            service_name = conf[:service_name]
            instances = conf[:misc]['instances']
            instances.times do |i|
                service_name_i = "#{service_name}-#{i+1}"
                systemctl(['status', "#{service_name_i}.service"])
            end
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end
    
    def create_nodejs(conf)
        cf_system = cf_system()
        site = conf[:site]
        type = conf[:type]
        user = conf[:user]
        site_dir = conf[:site_dir]
        service_name = conf[:service_name]

        run_dir = "/run/#{service_name}"
        
        misc = conf[:misc]
        nvm_dir = misc['nvm_dir']
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
        mem_per_conn_kb = tune.fetch('mem_per_conn_kb', 1024).to_i
        max_conn = (mem_limit - mem_fixed) * 1024 / mem_per_conn_kb
        
        if max_conn < 1
            fail("Not enough memory for #{site} #{type}")
        end
        
        saveMaxConn(site, type, max_conn * instances)
        
        new_mem_ratio = tune.fetch('new_mem_ratio', 0.25).to_f
        new_mem = (mem_limit * new_mem_ratio).to_i
        old_mem = mem_limit - new_mem
        
        node_env = tune.fetch('node_env', 'production')
        services = []
        
        instances.times do |i|
            i += 1
            service_name_i = "#{service_name}-#{i+1}"
            
            content_ini = {
                'Unit' => {
                    'Description' => "CFWEB NodeJS #{site} ##{i}",
                },
                'Service' => {
                    'Environment' => [
                        "HTTP_PORT=#{sock_base}.#{i}",
                        "NODE_VERSION=#{version}",
                        "NODE_ENV=#{node_env}",
                    ],
                    'LimitNOFILE' => 'infinity',
                    'ExecStart' => [
                            "#{nvm_dir}/nvm-exec",
                            '--nouse-idle-notification',
                            '--expose-gc',
                            "--max-old-space-size=#{old_mem}",
                            "--max-new-space-size=#{new_mem}",
                            "./#{entry_point}",
                    ].join(' '),
                    'WorkingDirectory' => "#{site_dir}/current",
                    'Slice' => "#{user}.slice",
                },
            }
            
            service_changed = self.cf_system().createService({
                :service_name => service_name_i,
                :user => user,
                :content_ini => content_ini,
                :cpu_weight => conf[:cpu_weight],
                :io_weight => conf[:io_weight],
                :mem_limit => mem_limit,
            })
            
            if service_changed
                systemctl('restart', "#{service_name_i}.service")
            end
            
            services << service_name_i
        end
        
        return services
    end
end
