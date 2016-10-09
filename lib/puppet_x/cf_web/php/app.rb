
module PuppetX::CfWeb::Php::App
    include PuppetX::CfWeb::Php
    
    def check_php(conf)
        begin
            service_name = conf[:service_name]
            systemctl(['status', "#{service_name}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end
    
    def create_php(conf)
        cf_system = cf_system()
        site = conf[:site]
        type = conf[:type]
        user = conf[:user]
        site_dir = conf[:site_dir]
        service_name = conf[:service_name]

        run_dir = "/run/#{service_name}"
        pid_file = "#{run_dir}/php-fpm.pid"
        sock_file = "#{run_dir}/php-fpm.sock"
        
        misc = conf[:misc]
        fpm_tune = misc['fpm_tune']
        is_debug = misc['is_debug']
        memcache = misc['memcache']
        extension = misc['extension']
        
        conf_dir = "#{site_dir}/.php"
        php_ini_file = "#{conf_dir}/php.ini"
        fpm_conf_file = "#{conf_dir}/fpm.conf"
        
        # PHP ini conf
        #---
        php_ini = {
            'date.timezone' => 'Etc/UTC',
            'display_errors' => 0,
            'display_startup_errors' => 0,
            'error_log' => 'syslog',
            'log_errors' => 1,
            'magic_quotes_gpc' => 0,
            'max_input_nesting_level' => 3,
            'mbstring.func_overload' => 1,
            'memory_limit' => '32M',
            'open_basedir' => site_dir,
            'output_buffering' => 8192,
            'session.name' => 'SESSID',
            'session.use_strict_mode' => 1,
            'upload_max_filesize' => '1M',
        }
        php_ini.merge! misc['php_ini']
        php_ini.merge!({
            'cgi.fix_pathinfo' => 1,
            'doc_root' => "#{site_dir}/current",
            'enable_dl' => 0,
            'expose_php' => 0,
            'extension' => extension.map { |v| "#{v}.so" },
            'sys_temp_dir' => "#{site_dir}/tmp",
        })
        
        if memcache
            memservers = [ "tcp://#{memcache['host']}:#{memcache['port']}"]
            memservers += memcache['servers'].map { |v| "tcp://#{v['host']}:#{v['port']}" }
            php_ini.merge!({
                'session.save_handler' => 'memcache',
                'session.save_path' => memservers.join(','),
                'memcache.allow_failover' => 1,
                'memcache.session_redundancy' => memcache['servers'].size + 2,
            })
        end
        
        php_changed = cf_system.atomicWriteIni(
            php_ini_file,
            { 'global' => php_ini },
            { :user => user }
        )
        
        # FPM conf
        #---
        if is_debug
            pm = 'ondemand'
        else
            pm = 'static'
        end
        
        
        # defaults
        fpm_conf = {
            'global' => {
                'error_log' => 'syslog',
                'syslog.facility' => 'daemon',
                'syslog.ident' => 'php-fpm',
                'log_level' => 'notice',
                'emergency_restart_threshold' => 10,
                'emergency_restart_interval' => 300,
                'process_control_timeout' => '60s',
                'rlimit_files' => 10240,
                'rlimit_core' => 0,
            }.merge(fpm_tune.fetch('global', {})),
            'pool' => {
                'listen.backlog' => -1,
                'pm' => pm,
                'pm.max_requests' => 10000,
                'security.limit_extensions' => '.php',
            }.merge(fpm_tune.fetch('pool', {})),
        }
        
        # tune
        fpm_conf.each { |k, v|
            v.merge! fpm_tune.fetch(k, {})
        }
        
        # forced
        mem_limit = cf_system.getMemory(service_name)
        conn_mem = php_ini['memory_limit'].to_i
        
        if memcache
            memcache_sessions = memcache['sessions']
            
            if memcache_sessions.is_a? Integer
                mem_limit_memcache = memcache_sessions
            else
                mem_limit_memcache = (mem_limit * 0.1).to_i
            end
            
            mem_limit -= mem_limit_memcache
        end
        
        max_conn = (mem_limit / conn_mem).to_i
        
        if max_conn < 1
            fail("Not enough memory for #{site} #{type}")
        end
        
        saveMaxConn(site, type, max_conn)
        
        fpm_conf['global'].merge!({
            'pid' => pid_file,
            'daemonize' => 'no',
            'systemd_interval' => 10,
        })
        fpm_conf['pool'].merge!({
            'user' => user,
            'group' => user,
            'listen' => sock_file,
            'listen.owner' => user,
            'listen.group' => user,
            'listen.mode' => '0660',
            'pm.max_children' => max_conn,
        })
        fpm_changes = cf_system.atomicWriteIni(
                fpm_conf_file,
                fpm_conf,
                { :user => user }
        )
        
        # Memcached
        #---
        if memcache
            # TODO: actual max conn per server should be used
            memcache_maxconn = max_conn * (memcache['servers'].size+1) * 10
            port = cf_system.genPort("cfweb/#{site}-phpsess", memcache['port'])
            content_ini = {
                'Unit' => {
                    'Description' => "CFWEB PHPSESS #{site}",
                },
                'Service' => {
                    'LimitNOFILE' => memcache_maxconn,
                    'ExecStart' => [
                            "/usr/bin/memcached",
                            "-m #{mem_limit_memcache}",
                            "-c #{memcache_maxconn}",
                            "-t 1",
                            "-l #{memcache['host']}:#{port}",
                    ].join(' '),
                    'WorkingDirectory' => site_dir,
                    'Slice' => "#{user}.slice",
                },
            }
            
            memcache_service = "#{service_name}sess"
            
            memcache_changed = self.cf_system().createService({
                :service_name => memcache_service,
                :user => user,
                :content_ini => content_ini,
                :mem_limit => mem_limit_memcache,
            })
            
            if memcache_changed
                systemctl('restart', "#{memcache_service}.service")
            end
        end
        
        # Service
        #---
        content_ini = {
            'Unit' => {
                'Description' => "CFWEB PHP #{site}",
            },
            'Service' => {
                'LimitNOFILE' => fpm_conf['global']['rlimit_files'],
                'PIDFile' => pid_file,
                'ExecStart' => [
                        "/usr/sbin/#{misc['fpm_bin']} -c #{php_ini_file}",
                        "--pid #{pid_file}",
                        "--fpm-config #{fpm_conf_file}",
                        '--nodaemonize',
                ].join(' '),
                'ExecReload' => '/bin/kill -s USR2 $MAINPID',
                'WorkingDirectory' => site_dir,
                'Slice' => "#{user}.slice",
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
            systemctl('start', "#{service_name}.service")
        end
        
        #---
        if php_changed or fpm_changes or service_changed
            systemctl(['reload', "#{service_name}.service"])
        end
    end
end
