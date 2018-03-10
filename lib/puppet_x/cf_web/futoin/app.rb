#
# Copyright 2016-2018 (c) Andrey Galkin
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
                ep = futoin_conf['entryPoints'][name]
                
                next if ep['tool'] == 'nginx'
                
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
    
    def prep_nginx_config(config_hash, prefix="")
        content = []

        config_hash.each do |k, v|
            next if v.is_a? Hash
            
            if k[0] == '-'
                v = v.split("\n")
                v.each { |x|
                    content << "#{prefix}#{x}"
                }
            elsif v.is_a? Array
                v.each { |lv|
                    content << "#{prefix}#{k} #{lv};"
                }
            else
                content << "#{prefix}#{k} #{v};"
            end
        end
        
        config_hash.each do |k, v|
            next unless v.is_a? Hash
            
            content << ""
            content << "#{prefix}#{k} {"
            content += prep_nginx_config(v, "#{prefix}  ")
            content << "#{prefix}}"
            content << ""
        end

        return content
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
        persist_dir = misc['persist_dir']
        
        mem_limit = cf_system.getMemory(service_name)

        run_dir = "/run/#{service_name}"
        deployer_group = "deployer_#{site}"
        
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
            "--#{url_arg}=#{deploy_conf['tool']}:#{deploy_conf['url']}",
            "--deployDir=#{site_dir}",
        ]
        
        redeploy_file = "#{site_dir}/.redeploy"
        redeploy = File.exists? redeploy_file
        deploy_futoin_file = "#{site_dir}/futoin.json"
        
        current_file = "#{site_dir}/current"
        orig_current = nil
        orig_current = File.readlink(current_file) if File.exists? current_file
        
        warning("CID deploy: #{site_dir}")
        orig_cwd = Dir.pwd
        
        begin
            Dir.chdir(site_dir)
            pre_conf = ''
            pre_conf = File.read(deploy_futoin_file) if File.exists? deploy_futoin_file
            
            # Basic setup
            #---
            Puppet::Util::Execution.execute(
                [
                    '/usr/local/bin/cid',
                    'deploy', 'setup',
                    "--user=#{user}",
                    "--group=#{user}",
                    "--limit-memory=#{mem_limit}M",
                ],
                {
                    :failonfail => true,
                    :uid => user,
                    :gid => deployer_group,
                }
            )
            
            # Extra setup
            #---
            cid_vesion = Puppet::Util::Execution.execute(
                [
                    '/usr/local/bin/cid', '--version'
                ],
                {
                    :failonfail => true,
                    :uid => user,
                    :gid => deployer_group,
                }
            ).strip()
            
            phpfpm_tune = {
                'phpini' => {
                    'open_basedir' => [
                        "#{File.realpath(site_dir)}/",
                        "#{File.realpath(persist_dir)}/",
                    ].join(':'),
                }
            }
            
            uwsgi_tune = {
                'uwsgi' => {
                    'chmod-socket' => '660',
                    'pythonpath' => File.join(site_dir, 'current'),
                },
            }
            
            deploy_set = [
                %Q{tooltune cid version=#{Shellwords.escape(cid_vesion)}},
                %Q{tooltune phpfpm #{Shellwords.escape(JSON.generate(phpfpm_tune))}},
                %Q{tooltune uwsgi #{Shellwords.escape(JSON.generate(uwsgi_tune))}},
                %Q{env syslogTag #{service_name}}
            ] + (deploy_conf['deploy_set'] || [])
            
            deploy_set.each do |v|
                res = Puppet::Util::Execution.execute(
                    [
                        '/usr/local/bin/cid',
                        'deploy', 'set'] +
                        Shellwords.split(v),
                    {
                        :uid => user,
                        :gid => deployer_group,
                    }
                )
                
                if res.exitstatus != 0
                    err("\n---\n#{res}---")
                    raise "Failed at deploy set: #{v}"
                end
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
                        :gid => deployer_group,
                    }
                )
            end
            
            # Actual deployment
            #---
            redeploy = true if pre_conf != File.read(deploy_futoin_file)
            deploy_args << '--redeploy' if redeploy

            res = Puppet::Util::Execution.execute(
                [
                    '/usr/local/bin/cid',
                    'deploy',
                ] + deploy_args,
                {
                    :failonfail => false,
                    :combine => true,
                    :uid => user,
                    :gid => deployer_group,
                }
            )
            
            new_current = File.readlink(current_file)
            redeploy ||= (new_current != orig_current)
                
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
            
            File.unlink redeploy_file if File.exists? redeploy_file
        rescue Exception => e
            # allow to continue, to keep services running
            #---
            futoin_conf_file = "#{site_dir}/.futoin.merged.json"
            raise e unless File.exists? futoin_conf_file
            
            err(e.to_s)
            
            futoin_conf = File.read(futoin_conf_file)
            futoin_conf = JSON.parse(futoin_conf)
            
            res = []
            
            futoin_conf['deploy']['autoServices'].each do |name, instances|
                ep = futoin_conf['entryPoints'][name]
                
                next if ep['tool'] == 'nginx'
                
                i = 0
                
                instances.each do |v|
                    res << "#{service_name}_#{name}-#{i}"
                    i += 1
                end
            end
            
            return res
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
        
        if webcfg['main']
            mounts['/'] ||= {}
            mounts['/']['app'] = webcfg['main']
        end
        
        # Nginx config
        #---
        vhost_global = []
        vhost_server = []
        
        webroot = webcfg['root']
        vhost_server << "root #{File.join(site_dir, 'current', webroot)};" if webroot
        
        vhost_server << limits['static']['expr']
        
        upstream_zone_size = tune.fetch('upstreamZoneSize', '64k')
        fail_timeout = tune.fetch('upstreamFailTimeout', '0')
        keep_alive_percent = tune.fetch('upstreamKAPercent', 25).to_i
        upstream_queue = tune.fetch('upstreamQueue', nil)
        
        autoServiceLocations = {}
        
        autoServices.each do |name, instances|
            ep = entryPoints[name]
            ep_tool = ep['tool']
            
            if ep_tool == 'nginx'
                ep_tune = ep.fetch('tune', {})
                extra_conf = (
                    ep_tune
                        .fetch('config', {})
                        .fetch('http', {})
                        .fetch('server', {})
                )
                
                vhost_server += prep_nginx_config(extra_conf)
                
                next
            end
            
            protocol = instances[0]['socketProtocol']
            next if protocol == 'custom'
            
            upstream_name = "futoin_#{site}_#{name}"
            
            vhost_global << "upstream #{upstream_name} {"
            
            if upstream_queue
                vhost_global << "  queue #{upstream_queue};"
                vhost_global << "  zone upstreams #{upstream_zone_size};"
                vhost_global << "  hash $binary_remote_addr consistent;"
            else
                vhost_global << "  least_conn;"
            end
            
            #--
            keepalive = ['fcgi', 'http'].include? protocol
            force_maxconn = ['node'].include? ep_tool
            
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
                options << "max_fails=0"
                options << "fail_timeout=#{fail_timeout}"

                if upstream_queue
                    options << "max_conns=#{v['maxConnections']}"
                elsif force_maxconn
                    options << "max_conns=#{v['maxConnections']}"
                end

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
                elsif !socket_type
                    next
                else
                    raise %Q{Unsupported socket type "#{socket_type}" for "#{name}"}
                end

                vhost_global << %Q{  server #{socket} #{options.join(' ')};}
            end
            
            #--
            vhost_global << "}"
            vhost_global << ""
            
            #================
            next_tries = instances.size
            body_size = instances[0]['maxRequestSize'].downcase
            
            #--
            location_conf = []
            
            if limits[name]
                location_conf << "  #{limits[name]['expr']}"
            else
                location_conf << "  #{limits['dynamic']['expr']}"
            end
            
            location_conf << "  client_max_body_size #{body_size};";
            
            if protocol == 'http'
                location_conf << "  proxy_pass http://#{upstream_name};"
                location_conf << "  proxy_next_upstream_tries #{next_tries};"
                location_conf << "  include /etc/nginx/cf_http_params;"
            elsif protocol == 'fcgi'
                location_conf << "  fastcgi_pass #{upstream_name};"
                location_conf << "  fastcgi_next_upstream_tries #{next_tries};"
                location_conf << "  include /etc/nginx/cf_fastcgi_params;"
                file_path = File.join(site_dir, 'current', ep.fetch('path', ''))
                location_conf << "  fastcgi_param SCRIPT_FILENAME #{file_path};"
            elsif protocol == 'scgi'
                location_conf << "  scgi_pass #{upstream_name};"
                location_conf << "  scgi_next_upstream_tries #{next_tries};"
                location_conf << "  include /etc/nginx/cf_scgi_params;"
            elsif protocol == 'uwsgi'
                location_conf << "  uwsgi_pass #{upstream_name};"
                location_conf << "  uwsgi_next_upstream_tries #{next_tries};"
                location_conf << "  include /etc/nginx/cf_uwsgi_params;"
            elsif protocol == 'custom'
                next
            else
                raise "Not supported protocol '#{protocol}'"
            end
            
            autoServiceLocations[name] = location_conf
            
            vhost_server << "location @#{name} {"
            vhost_server += location_conf
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
        vhost_server << "location ~ /\\. {"
        vhost_server << "  deny all;"
        vhost_server << "  limit_req zone=unlikely nodelay;"
        vhost_server << "  log_not_found off;"
        vhost_server << "}"
        vhost_server << ""
        
        # App-defined mounts
        #---        
        mounts.each do |path, mp|
            mp = { 'app' => mp } if mp.is_a? String
            
            vhost_server << "location #{path} {"
            #---
            app = mp['app']
            path_tune = mp.fetch('tune', {})
            serve_static = mp.fetch('static', false)
            
            if app
                if serve_static
                    vhost_server << "  try_files $uri @#{app};"
                else
                    vhost_server += autoServiceLocations[app]
                end
            else
                serve_static = true # force
            end
            
            if serve_static
                vhost_server << "  disable_symlinks if_not_owner;"
                vhost_server << "  index #{path_tune.fetch('index', 'index.html')};"
                
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
                
                vhost_server << "  expires #{path_tune.fetch('expires', 'max')};"
                
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
                    
                    vhost_server << "  location ~* \\.(#{text_assets.join('|')})$ {"
                        if path_tune.fetch('gzip', true)
                            vhost_server << "    gzip on;"
                            vhost_server << "    gzip_types *;"
                        else
                            vhost_server << "    gzip off;"
                        end
                        
                        if path_tune.fetch('staticGzip', true)
                            vhost_server << "    gzip_static on;"
                        else
                            vhost_server << "    gzip_static off;"
                        end
                    vhost_server << "  }"
                else
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
            tool = futoin_conf['entryPoints'][name]['tool']
            next if tool == 'nginx'
            
            max_conn = 0
            i = 0
            mem_lock = ['uwsgi'].include? tool
            
            instances.each do |v|
                service_name_i = "#{service_name}_#{name}-#{i}"
                service_names << service_name_i
                max_conn += v['maxConnections']
                
                content_ini = {
                    'Unit' => {
                        'Description' => "CFWEB App: #{site} (#{name}-#{i})",
                    },
                    'Service' => {
                        'LimitNOFILE' => 'infinity',
                        'WorkingDirectory' => "#{site_dir}",
                        'Slice' => "#{PuppetX::CfWeb::SLICE_PREFIX}#{user}.slice",
                        'ExecStart' => "/usr/local/bin/cid service exec #{name} #{i}",
                        'ExecReload' => %Q{/usr/local/bin/cid service reload #{name} #{i} "$MAINPID"},
                        'ExecStop' => %Q{/bin/sh -c '[ -n "$MAINPID" ] && /usr/local/bin/cid service stop #{name} #{i} $MAINPID || /bin/true'},
                    },
                }
                
                sock_path = v['socketPath']
                
                # Workaround for Node.js & misc.
                if sock_path
                    script = "while ! chmod 0770 -f #{sock_path}; do sleep 0.01; done"
                    content_ini['Service']['ExecStartPre'] = "/bin/rm -f #{sock_path}"
                    content_ini['Service']['ExecStartPost'] = "/bin/sh -c '#{script}'"
                end
                
                service_changed = self.cf_system().createService({
                    :service_name => service_name_i,
                    :user => user,
                    :content_ini => content_ini,
                    :mem_limit => v['maxMemory'],
                    :mem_lock => mem_lock,
                })
                
                begin
                    if service_changed
                        # if unit changes then we need to restart to get new limits working
                        systemctl('restart', "#{service_name_i}.service")
                    elsif redeploy
                        systemctl('reload-or-restart', "#{service_name_i}.service")
                    else
                        systemctl('start', "#{service_name_i}.service")
                    end
                rescue Exception => e
                    err(e.to_s)
                end
                
                i += 1
            end
            
            saveMaxConn(site, name, max_conn)
        end

        # Make sure nginx is refresh as well
        #---
        begin
            systemctl('reload', "cfnginx.service")
        rescue Exception => e
            warning(e.to_s)
        end
        
        return service_names
    end
end
