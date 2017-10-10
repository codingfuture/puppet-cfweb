#
# Copyright 2016-2017 (c) Andrey Galkin
#

require 'json'
require 'shellwords'

module PuppetX::CfWeb::Futoin::App
    include PuppetX::CfWeb::Futoin
    
    def check_futoin(conf)
        begin
            site_dir = conf[:site_dir]
            service_name = conf[:service_name]
            
            futoin_conf_file = "#{site_dir}/.futoin.merged.json"
            return false unless File.exists? futoin_conf_file
            
            futoin_conf = File.read(futoin_conf_file)
            futoin_conf = JSON.parse(futoin_conf)
            
            futoin_conf['deploy']['autoServices'].each do |name, instances|
                info = futoin_conf['entryPoints'][name]
                
                next if info['tool'] == 'nginx'
                
                i = 0
                
                instances.each do |v|
                    service_name_i = "#{service_name}_#{name}-#{i}"
                    i += 1
                    systemctl(['status', "#{service_name_i}.service"])
                end
            end
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
        misc = conf[:misc]
        
        deploy_conf = misc['deploy']
        limits = misc['limits']
        conf_prefix = misc['conf_prefix']
        tune = misc['tune']
        
        mem_limit = cf_system.getMemory(service_name)

        run_dir = "/run/#{service_name}"
        
        #---
        if deploy_conf['type'] == 'rms'
            url_arg = 'rmsRepo'
            deploy_args = [
                'rms',
                deploy_conf['pool']
            ]
        else
            url_arg = 'vcsRepo'
            deploy_args = [ deploy_conf['type'] ]
        end
        
        if deploy_conf['match']
            deploy_args += [ deploy_conf['match'] ]
        end
        
        deploy_args += [
            "--#{url_arg}=#{deploy_conf['url']}",
            "--limit-memory=#{mem_limit}M",
            "--deployDir=#{site_dir}",
        ]
        
        warning("CID deploy: #{site_dir}")
        orig_cwd = Dir.pwd
        
        begin
            Dir.chdir(site_dir)
            
            # Basic setup
            #---
            Puppet::Util::Execution.execute(
                [
                    '/usr/local/bin/cid',
                    'deploy', 'setup',
                    "--user=#{user}",
                    "--group=#{user}",
                ],
                {
                    :failonfail => true,
                    :uid => user,
                    :gid => user,
                }
            )
            
            # Extra setup
            #---
            (deploy_conf['deploy_set'] || []).each do |v|
                Puppet::Util::Execution.execute(
                    [
                        '/usr/local/bin/cid',
                        'deploy', 'set'] +
                        Shellwords.split(v),
                {
                    :failonfail => true,
                    :uid => user,
                    :gid => user,
                }
                )
            end
            
            # Custom script
            #---
            custom_script = deploy_conf['custom_script']
            
            if custom_script
                custom_script_file = '.custom_script'
                
                cf_system.atomicWrite(
                    custom_script_file, custom_script,
                    {
                        :user => user,
                        :mode => 0700,
                    }
                )
                
                Puppet::Util::Execution.execute(
                    [ 'bash', custom_script_file ],
                    {
                        :failonfail => true,
                        :uid => user,
                        :gid => user,
                    }
                )
            end
            
            # Actual deployment
            #---
            res = Puppet::Util::Execution.execute(
                [
                    '/usr/local/bin/cid',
                    'deploy',
                ] + deploy_args,
                {
                    :failonfail => false,
                    :combine => true,
                    :uid => user,
                    :gid => user,
                }
            )
            
                
            cf_system.atomicWrite(
                '.deploy.log', res,
                {
                    :user => user,
                    :mode => 0600,
                    :show_diff => false
                }
            )
            
            if res.exitstatus != 0
                warning("\n---\n#{res}---")
                raise 'Failed to deploy'
            else
                info("\n---\n#{res}---")
            end
        ensure
            Dir.chdir(orig_cwd)
        end
        
        #---
        futoin_conf = File.read("#{site_dir}/.futoin.merged.json")
        futoin_conf = JSON.parse(futoin_conf)
        
        entryPoints = futoin_conf['entryPoints']
        autoServices = futoin_conf['deploy']['autoServices']
        webcfg = futoin_conf.fetch('webcfg', {})
        mounts = webcfg.fetch('mounts', {}).clone
        
        mounts['/'] = webcfg['main'] if webcfg['main']
        
        # Nginx config
        #---
        vhost_global = []
        vhost_server = []
        
        webroot = webcfg['webroot']
        vhost_server << "root #{File.join(site_dir, 'current', webroot)};" if webroot
        
        vhost_server << limits['static']['expr']
        
        upstream_zone_size = tune.fetch('upstreamZoneSize', '64k')
        fail_timeout = tune.fetch('upstreamFailTimeout', '10')
        keep_alive_percent = tune.fetch('upstreamKAPercent', 25).to_i
        upstream_queue = tune.fetch('upstreamQueue', nil)
        
        autoServices.each do |name, instances|
            info = entryPoints[name]
            
            if info['tool'] == 'nginx'
                next
            end
            
            protocol = instances[0]['socketProtocol']
            upstream_name = "futoin_#{site}_#{name}"
            
            vhost_global << "upstream #{upstream_name} {"
            vhost_global << "  zone upstreams #{upstream_zone_size};"
            vhost_global << "  hash $binary_remote_addr consistent;"
            
            if upstream_queue
                vhost_global << "  queue #{upstream_queue};"
            end
            
            #--
            keepalive = ['fcgi', 'http'].include? protocol
            
            if keepalive and keep_alive_percent > 0
                ka_conn = instances.reduce(0) { |m, v| m + v['maxConnections'] }
                ka_conn = (ka_conn * keep_alive_percent / 100).to_i

                if ka_conn > 0
                    vhost_global << "  keepalive #{ka_conn};"
                end
            end
            
            #--
            instances.each do |v|
                options = []
                options << "max_conns=#{v['maxConnections']}"
                options << "max_fails=0"
                options << "fail_timeout=#{fail_timeout}"

                socket_type = v['socketType']

                if socket_type == 'unix'
                    socket = "unix:#{v['socketPath']}"
                elsif socket_type == 'tcp'
                    sock_addr = v['socketAddress']

                    if sock_addr == '0.0.0.0'
                        sock_addr = '127.0.0.1'
                    end

                    socket = "#{sock_addr}:#{v['socketPort']}"
                elsif socket_type == 'tcp6'
                    sock_addr = v['socketAddress']

                    if sock_addr == '::'
                        sock_addr = '::1'
                    end

                    socket = "#{sock_addr}:#{v['socketPort']}"
                else
                    raise %Q{Unsupported socket type "#{socket_type}" for "#{app}"}
                end

                vhost_global << %Q{  server #{socket} #{options.join(' ')};}
            end
            
            #--
            vhost_global << "}"
            vhost_global << ""
            
            #================
            next_tries = instances.size - 1
            body_size = instances[0]['maxRequestSize'].downcase
            
            #--
            vhost_server << "location @#{name} {"
            
            if limits[name]
                vhost_server << "  #{limits[name]['expr']}"
            else
                vhost_server << "  #{limits['dynamic']['expr']}"
            end
            
            vhost_server << "  client_max_body_size #{body_size};";
            
            if protocol == 'http'
                vhost_server << "  proxy_pass http://#{upstream_name};"
                vhost_server << "  proxy_next_upstream_tries #{next_tries};"
                vhost_server << "  include /etc/nginx/cf_http_params;"
            elsif protocol == 'fcgi'
                vhost_server << "  fastcgi_pass #{upstream_name};"
                vhost_server << "  fastcgi_next_upstream_tries #{next_tries};"
                vhost_server << "  include /etc/nginx/cf_fastcgi_params;"
                file_path = File.join(site_dir, 'current', info.fetch('path', ''))
                vhost_server << "  fastcgi_param SCRIPT_FILENAME #{file_path};"
            elsif protocol == 'scgi'
                vhost_server << "  scgi_pass #{upstream_name};"
                vhost_server << "  scgi_next_upstream_tries #{next_tries};"
                vhost_server << "  include /etc/nginx/cf_scgi_params;"
            elsif protocol == 'uwsgi'
                vhost_server << "  uwscgi_pass #{upstream_name};"
                vhost_server << "  uwscgi_next_upstream_tries #{next_tries};"
                vhost_server << "  include /etc/nginx/cf_uwscgi_params;"
            else
                raise "Not supported protocol '#{protocol}'"
            end
            
            vhost_server << "}"
            vhost_server << ""
        end
        
        # favicon
        #---
        vhost_server << "location /favicon.ico {"
        vhost_server << "  try_files $uri @empty_gif;"
        vhost_server << "}"
        vhost_server << "location @empty_gif {"
        vhost_server << "  expires 1h;"
        vhost_server << "  empty_gif;"
        vhost_server << "}"
        vhost_server << ""
        
        # Forbid dot-files
        #---
        vhost_server << "location ~ /\. {"
        vhost_server << "  deny all;"
        vhost_server << "  limit_req zone=unlikely nodelay;"
        vhost_server << "  log_not_found off;"
        vhost_server << "}"
        vhost_server << ""
        
        # App-defined mounts
        #---        
        mounts.each do |path, info|
            info = { 'app' => info } if info.is_a? String
            
            vhost_server << "location #{path} {"
            #---
            app = info['app']
            path_tune = info.fetch('tune', {})
            serve_static = info.fetch('static', false)
            
            if app
                if serve_static
                    vhost_server << "  try_files $uri $uri/ @#{app};"
                else
                    vhost_server << "  try_files /FAKE-WORKAROUND @#{app};"
                end
            else
                serve_static = true # force
            end
            
            if serve_static
                if path_tune.fetch('etag', false)
                    vhost_server << "  etag on;"
                else
                    vhost_server << "  etag off;"
                end
                
                if path_tune.fetch('autoindex', false)
                    vhost_server << "  autoindex on;"
                else
                    vhost_server << "  autoindex off;"
                end
                
                if path_tune.fetch('pattern', true)
                    text_assets = [
                        'html',
                        'htm',
                        'txt',
                        'css',
                        'js',
                        'svg',
                        'xml',
                    ]
                    
                    vhost_server << "  location ~* \.(#{text_assets.joim('|')})$ {"
                        if path_tune.fetch('gzip', true)
                            vhost_server << "  gzip on;"
                            vhost_server << "  gzip_types *;"
                        else
                            vhost_server << "  gzip off;"
                        end
                        
                        if path_tune.fetch('staticGzip', true)
                            vhost_server << "  gzip_static on;"
                        else
                            vhost_server << "  gzip_static off;"
                        end
                    vhost_server << "  }"
                else
                    vhost_server << "  expires #{path_tune.fetch('expires', 'max')};"
                
                    if path_tune.fetch('gzip', false)
                        vhost_server << "  gzip on;"
                        vhost_server << "  gzip_types *;"
                    else
                        vhost_server << "  gzip off;"
                    end
                    
                    if path_tune.fetch('staticGzip', false)
                        vhost_server << "  gzip_static on;"
                    else
                        vhost_server << "  gzip_static off;"
                    end
                end
            end
            
            #---
            vhost_server << "}"
            vhost_server << ""
        end
        
        vhost_global_file = "#{conf_prefix}.global.futoin"
        vhost_server_file = "#{conf_prefix}.server.futoin"
        
        cf_system.atomicWrite(vhost_global_file, vhost_global.join("\n"))
        cf_system.atomicWrite(vhost_server_file, vhost_server.join("\n"))
        
        # Services
        #---
        service_names = []
        
        autoServices.each do |name, instances|
            info = entryPoints[name]
            
            next if info['tool'] == 'nginx'
            
            max_conn = 0
            i = 0
            
            instances.each do |v|
                service_name_i = "#{service_name}_#{name}-#{i}"
                service_names << service_name_i
                max_conn += v['maxConnections']
                
                content_ini = {
                    'Unit' => {
                        'Description' => "CFWEB App: #{site}",
                    },
                    'Service' => {
                        'LimitNOFILE' => 'infinity',
                        'WorkingDirectory' => "#{site_dir}",
                        'Slice' => "#{PuppetX::CfWeb::SLICE_PREFIX}#{user}.slice",
                        'ExecStart' => "/usr/local/bin/cid service exec #{name} #{i}",
                        'ExecReload' => "/usr/local/bin/cid service reload #{name} #{i} $MAINPID",
                        'ExecStop' => "/usr/local/bin/cid service stop #{name} #{i} $MAINPID",
                    },
                }
                
                service_changed = self.cf_system().createService({
                    :service_name => service_name_i,
                    :user => user,
                    :content_ini => content_ini,
                    :mem_limit => v['maxMemory'],
                })
                
                if service_changed
                    systemctl('reload-or-restart', "#{service_name_i}.service")
                end
                
                # make sure it's running
                systemctl('start', "#{service_name_i}.service")
                
                i += 1
            end
            
            saveMaxConn(site, name, max_conn)
        end

        # Service
        #---
        
        return service_names
    end
end
