
require File.expand_path( '../../../../puppet_x/cf_web', __FILE__ )

Puppet::Type.type(:cfweb_nginx).provide(
    :cfweb,
    :parent => PuppetX::CfWeb::ProviderBase
) do
    desc "Provider for cfweb_nginx"
    
    commands :systemctl => '/bin/systemctl'
    NGINX = '/usr/sbin/nginx' unless defined? NGINX
    
    def self.get_config_index
        'cf30web4_nginx'
    end

    def self.get_generator_version
        cf_system().makeVersion(__FILE__)
    end

    def self.on_config_change(newconf)
        return if newconf.empty?
        
        newconf = newconf[newconf.keys[0]]
        cf_system = self.cf_system()
        
        service_name = newconf[:service_name]
        
        conf_dir = '/etc/nginx'
        conf_file = "#{conf_dir}/nginx.conf"
        pid_file = "/run/#{service_name}/nginx.pid"
        run_dir = "/run/#{service_name}"
        
        user = service_name
        settings_tune = newconf[:settings_tune]

        # Config File
        #==================================================
        cfweb_tune = settings_tune.fetch('cfweb', {})
        extra_files = cfweb_tune.fetch('extra_files', 10000).to_i
        worker_processes = Facter['processors'].value['count']
        mem_limit = cf_system.getMemory(service_name)
        mem_per_conn = cfweb_tune.fetch('mem_per_conn', 32).to_i
        
        
        global_conf = {
            'worker_processes' => worker_processes,
            'worker_cpu_affinity' => 'auto',
            'pcre_jit' => 'on',
            'error_log' => '/var/log/nginx/error.log warn',
        }.merge(settings_tune.fetch('global', {}))
        worker_processes = global_conf['worker_processes'].to_i
        
        events_conf = {
            'accept_mutex' => 'off',
            'multi_accept' => 'on',
            'worker_connections' => (mem_limit * 1024 / mem_per_conn / worker_processes).to_i,
        }.merge(settings_tune.fetch('events', {}))
        
        http_conf = {
            'limit_req_status' => 429,
            'limit_conn_status' => 429,
            'default_type' => 'default_type',
            'log_format main' => [
                    '\'$remote_addr - $remote_user [$time_local]',
                    '"$request" $status $body_bytes_sent "$http_referer"',
                    '"$http_user_agent" "$http_x_forwarded_for"\''
            ].join(' '),
            'access_log' => '/var/log/nginx/access.log main',
            'keepalive_timeout' => '125 120',
            'keepalive_requests' => 100,
            'client_header_timeout' => '10s',
            'client_body_timeout' => '30s',
            'send_timeout' => '60s',
            'lingering_close' => 'off',
            'lingering_time' => '10s',
            'open_file_cache' => 'max=20000 inactive=10m',
            'open_file_cache_errors' => 'on',
            'output_buffers' => '2 32k',
            'reset_timedout_connection' => 'on',
            'server_tokens' => 'off',
        }.merge(settings_tune.fetch('http', {}))
        
        global_conf.merge!({
            'user' => service_name,
            'worker_rlimit_nofile' => (
                    global_conf['worker_processes'].to_i *
                    events_conf['worker_connections'].to_i +
                    extra_files
            ),
            'pid' => pid_file,
        })
        
        conf = global_conf.merge({
            "# events" => '',
            'events' => events_conf,
            "# http" => '',
            'http' => http_conf.merge({
                "# use for WS & other proxing" => '',
                'map $http_upgrade $connection_upgrade' => {
                    'default' => 'upgrade',
                    "''" => 'close',
                },
                "# misc" => '',
                'include /etc/nginx/mime.types' => '',
                'include /etc/nginx/sites/*.conf' => '',
            })
        })
        
        conf = nginxConf(conf, 0)
        config_changed = cf_system.atomicWrite(conf_file, conf, {:user => user})
       
        
        # Service File
        #==================================================
        content_ini = {
            'Unit' => {
                'Description' => "CFWEB nginx",
            },
            'Service' => {
                'LimitNOFILE' => global_conf['worker_rlimit_nofile'],
                'Type' => 'forking',
                'PIDFile' => pid_file,
                'ExecStartPre' => "#{NGINX} -c #{conf_file} -p #{conf_dir} -t",
                'ExecStart' => "#{NGINX} -c #{conf_file} -p #{conf_dir}",
                'ExecReload' => '/bin/kill -s HUP $MAINPID',
                'ExecStop' => '/bin/kill -s QUIT $MAINPID',
                'PrivateTmp' => true,
                'WorkingDirectory' => conf_dir,
            },
        }
        
        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => 'root',
            :content_ini => content_ini,
            :cpu_weight => newconf[:cpu_weight],
            :io_weight => newconf[:io_weight],
            :mem_limit => mem_limit,
            :mem_lock => true,
        })
        
        cf_system.maskService("nginx")
        
        if service_changed
            systemctl('start', "#{service_name}.service")
        end
        
        #==================================================
        
        if config_changed or service_changed
            warning(">> reloading #{service_name}")
            systemctl('reload', "#{service_name}.service")
        end
    end
    
    def self.nginxConf(settings, level)
        content = []
        tab = '    ' * level
        settings.each do |k, v|
            if v.is_a? Hash
                content << ''
                content << "#{tab}#{k} {"
                content << nginxConf(v, level + 1)
                content << "#{tab}}"
                content << ''
            elsif k[0] == '#'
                content << ''
                content << ''
                content << "#{tab}#{k}"
                content << "#{tab}#---"
            elsif v == '' or v.nil?
                content << "#{tab}#{k};"
            else
                content << "#{tab}#{k} #{v};"
            end
        end
        
        content.join("\n") + "\n"
    end

end
