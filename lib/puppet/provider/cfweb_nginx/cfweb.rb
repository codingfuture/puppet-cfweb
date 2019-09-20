#
# Copyright 2016-2019 (c) Andrey Galkin
#


require File.expand_path( '../../../../puppet_x/cf_web', __FILE__ )

Puppet::Type.type(:cfweb_nginx).provide(
    :cfweb,
    :parent => PuppetX::CfWeb::ProviderBase
) do
    desc "Provider for cfweb_nginx"
    
    commands :systemctl => PuppetX::CfSystem::SYSTEMD_CTL

    NGINX = '/usr/sbin/nginx' unless defined? NGINX
    commands :nginx => NGINX
    
    def self.get_config_index
        'cf30web1_nginx'
    end

    def self.get_generator_version
        cf_system().makeVersion(__FILE__)
    end
    
    def self.check_exists(params)
        debug('check_exists')
        begin
            conf_dir = '/etc/nginx'
            conf_file = "#{conf_dir}/nginx.conf"

            systemctl(['status', "#{params[:service_name]}.service"]) and
                nginx(['-c', conf_file, '-p', conf_dir, '-t'])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
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
        limits = newconf[:limits]
        stress_hosts = newconf[:stress_hosts]

        # Config File
        #==================================================
        cfweb_tune = settings_tune.fetch('cfweb', {})
        extra_files = cfweb_tune.fetch('extra_files', 20000).to_i
        worker_processes = Facter['processors'].value['count']
        mem_limit = cf_system.getMemory(service_name)
        mem_per_conn = cfweb_tune.fetch('mem_per_conn', 128).to_i
        worker_connections = (mem_limit * 1024 / mem_per_conn / worker_processes).to_i
        ssl_sess_factor = cfweb_tune.fetch('ssl_sess_factor', 3).to_i
        ssl_sess_per_mb = 4000
        is_cluster = cfweb_tune.fetch('is_cluster', false)

        #---
        if cfweb_tune.fetch('use_syslog', false)
            access_log = "syslog:server=unix:/dev/hdlog,facility=local2,tag=access_#{service_name},nohostname vhosts"
            error_log = "syslog:server=unix:/dev/hdlog,facility=local1,tag=#{service_name},nohostname error"
            log_conf = {
                'error_log' => error_log,
                'access_log' => access_log,
            }
        else
            access_log = '/var/log/nginx/access.log vhosts'
            error_log = '/var/log/nginx/error.log error'
            log_conf = {}
        end
    
        config_changed = cf_system.atomicWrite(
            "#{conf_dir}/log.conf",
            nginxConf( log_conf, 0),
            {
                :user => user,
                :mode => 0640,
            }
        )

        #---        
        global_conf = {
            'worker_processes' => worker_processes,
            'worker_cpu_affinity' => 'auto',
            'pcre_jit' => 'on',
            'error_log' => error_log,
        }.merge(settings_tune.fetch('global', {}))
        worker_processes = global_conf['worker_processes'].to_i
        
        events_conf = {
            'accept_mutex' => 'off',
            'multi_accept' => 'on',
            'worker_connections' => worker_connections,
        }.merge(settings_tune.fetch('events', {}))
        
        max_conn = global_conf['worker_processes'].to_i *
                   events_conf['worker_connections'].to_i
        if is_cluster
            ssl_sess_cache = 'off'
        else
            ssl_sess_cache = (max_conn * ssl_sess_factor / ssl_sess_per_mb + 1).to_i
            ssl_sess_cache = "shared:SSL:#{ssl_sess_cache}m"
        end

        http_conf = {
            'default_type' => 'application/octet-stream',
            #
            'log_format main' => [
                    '\'$remote_addr - $remote_user [$time_local]',
                    '"$request" $status $body_bytes_sent "$http_referer"',
                    '"$http_user_agent"\''
            ].join(' '),
            'log_format vhosts' => [
                    '\'$host:$server_port $remote_addr - $remote_user [$time_local]',
                    '"$request" $status $body_bytes_sent "$http_referer"',
                    '"$http_user_agent" $request_time\''
            ].join(' '),
            'access_log' => access_log,
            #
            'keepalive_timeout' => '65 60',
            'keepalive_requests' => 100,
            'client_header_timeout' => '10s',
            'client_body_timeout' => '30s',
            'send_timeout' => '60s',
            'lingering_close' => 'off',
            'lingering_time' => '10s',
            'open_file_cache' => "max=#{extra_files} inactive=10m",
            'open_file_cache_valid' => '60s',
            'open_file_cache_errors' => 'on',
            'output_buffers' => '2 32k',
            'reset_timedout_connection' => 'on',
            'server_tokens' => 'off',
            'root' => '/www/empty',
            'etag' => 'off',
            #
            'ssl_session_cache' => ssl_sess_cache,
            'ssl_session_timeout' => '1d',
            #
            'resolver_timeout' => '5s',
            #
            'limit_req_status' => 429,
            'limit_req_log_level' => 'warn',
            'limit_conn_status' => 429,
            'limit_conn_log_level' => 'warn',
        }.merge(settings_tune.fetch('http', {}))

        # Limits
        #---
        
        one_mb = 1024**2
        
        http_conf["# global limit helper vars"] = ''
        http_conf["geo $cf_binary_remote_addr"] = geo_addr_conf = {
            'default' => '$binary_remote_addr'
        }
        http_conf["geo $cf_server_name"] = geo_server_name_conf = {
            'default' => '$server_name'
        }
        
        if stress_hosts && stress_hosts.size then
            stress_hosts.each { |shost|
                geo_addr_conf[shost] = "''"
                geo_server_name_conf[shost] = "''"
            }
        end
        
        http_conf["# global limits"] = ''
        limits.each do |zone, info|
            fail("Missing var option for limit #{zone}") unless info.has_key? 'var'
            
            if info['type'] == 'conn'
                entry_size = info.fetch('entry_size', 64)
                limit_conn_size = ((entry_size * max_conn + one_mb) / one_mb).to_i
                limit = "limit_conn_zone #{info['var']} zone=#{zone}:#{limit_conn_size}m"
            elsif info['type'] == 'req'
                fail("Missing rate option for limit #{zone}") unless info.has_key? 'rate'
                entry_size = info.fetch('entry_size', 128)
                limit_req_size = ((entry_size * max_conn + one_mb) / one_mb).to_i
                limit = "limit_req_zone #{info['var']} zone=#{zone}:#{limit_req_size}m rate=#{info['rate']}"
            else
                fail("Invalid zone limit defintion #{zone}")
            end
            
            http_conf[limit] = ''
        end
        
        # Misc. forced
        http_conf.merge!({
            "# use for WS & other proxing" => '',
            'map $http_upgrade $connection_upgrade' => {
                'default' => 'upgrade',
                "''" => 'keep-alive',
            },
            'map $http_x_forwarded_proto $cf_real_scheme_helper' => {
                "default" => '$http_x_forwarded_proto',
                "''" => '$scheme',
            },
            'map $realip_remote_addr $cf_real_scheme' => {
                "default" => '$cf_real_scheme_helper',
                "''" => '$scheme',
            },
            'map $cf_real_scheme $cf_real_https' => {
                "default" => "''",
                'https' => 'on',
            },
            "# misc" => '',
            'include /etc/nginx/cf_mime.types' => '',
            'include /etc/nginx/cf_tls.conf' => '',
            'include /etc/nginx/sites/*.conf' => '',
        })        
        
        #---
        global_conf.merge!({
            'user' => service_name,
            'worker_rlimit_nofile' => (max_conn + extra_files),
            'pid' => pid_file,
        })
        
        conf = global_conf.merge({
            "# events" => '',
            'events' => events_conf,
            "# http" => '',
            'http' => http_conf,
        })
        
        conf = nginxConf(conf, 0)
        config_changed = cf_system.atomicWrite(
            conf_file, conf,
            {
                :user => user,
                :mode => 0640,
            }
        )
       
        
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
        
        if service_changed
            cf_system.maskService("nginx")
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
