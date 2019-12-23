#
# Copyright 2019 (c) Andrey Galkin
#

module PuppetX::CfWeb::Docker::App
    include PuppetX::CfWeb::Docker
    
    def check_docker(conf)
        begin
            site_dir = conf[:site_dir]
            service_name = conf[:service_name]
            deploy_dir = conf[:misc]['deploy_dir'] || site_dir
            
            systemctl(['status', "#{service_name}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end

    def create_docker(conf)
        cf_system = cf_system()
        site = conf[:site]
        type = conf[:type]
        user = conf[:user]
        app_name = conf[:app_name]
        site_dir = conf[:site_dir]
        service_name = conf[:service_name]
        misc = conf[:misc]
        
        deploy_conf = misc['deploy']
        limits = misc['limits']
        tune = misc['tune']
        persist_dir = misc['persist_dir']
        deploy_dir = misc['deploy_dir']
        
        mem_limit = cf_system.getMemory(service_name)
        mem_limit = 1 if mem_limit == 0

        run_dir = "/run/#{service_name}"

        # Custom script
        #---
        orig_cwd = Dir.pwd
        
        begin
            Dir.chdir(deploy_dir)
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
        ensure
            Dir.chdir(orig_cwd)
        end

        # Services
        #---
        mounts = (deploy_conf['binds'] || {}).map { |k, v|
            %Q{--mount type=bind,source=#{persist_dir}/#{k},destination=#{v}}
        }

        #---
        hosts = deploy_conf.fetch('hosts', [])
        env_file = "#{deploy_dir}/.env"

        if File.exists? env_file
            env_entries = File.read(env_file).split("\n")

            env_entries.each do |l|
                l = l.split("=")
                next unless l[0].end_with?('HOST') || l[0].end_with?('NODES')

                l[1].tr('"', '').split(' ').each do |h|
                    begin
                        IPAddr.new h 
                    rescue
                        hosts << h
                    end
                end
            end
        end

        hosts.uniq!
        hosts = hosts.map { |v|
            %Q{--add-host '#{v}:#{Resolv.getaddress v}'}
        }

        #---
        image = deploy_conf['image']
        image_name = %Q{#{image['image']}:#{image.fetch('image_tag', 'latest')}}
        image_ver = Puppet::Util::Execution.execute(
            [ '/usr/bin/docker', 'image', 'ls',
              '--format', '{{ .ID }}{{ .Digest }}',
              image_name
            ],
            {
                :failonfail => true,
            }
        ).tr("\n", ':')

        #---
        config_hash = Digest::SHA256.hexdigest(
                conf.to_yaml +
                (deploy_conf.fetch('config_files', []).map { |v| File.read(v) }).join('')
        )

        #---
        network = deploy_conf.fetch('network', site)

        #---
        misc_args = []
        misc_args << %Q{--env-file=#{deploy_conf['env_file']}} if deploy_conf['env_file']

        #---
        content_ini = {
            'Unit' => {
                'Description' => "CFWEB App: #{site} (#{app_name})",
            },
            'Service' => {
                '# image ver' => image_ver,
                '# config digest' => config_hash,
                'LimitNOFILE' => 'infinity',
                'WorkingDirectory' => "#{deploy_dir}",
                'Slice' => "#{PuppetX::CfWeb::SLICE_PREFIX}#{user}.slice",
                'ExecStart' => ([
                    '/usr/bin/docker',
                    'run',
                    %Q{--name=#{service_name}},
                    %Q{--cgroup-parent=#{PuppetX::CfWeb::SLICE_PREFIX}#{user}},
                    #'--log-driver=syslog',
                    %Q{--memory-reservation=#{mem_limit}m},
                    %Q{--memory=#{(mem_limit*1.1).to_i}m},
                    %Q{--network=#{network}},
                    %Q{-p #{misc['bind_host']}:#{misc['bind_port']}:#{deploy_conf['target_port']}},
                    '--restart=no',
                    '--rm',
                ] + mounts + hosts + misc_args + deploy_conf['custom_args'] + [
                    image_name,
                ]).join(' '),
                'ExecStop' => [
                    '/usr/bin/docker',
                    'container stop',
                    service_name,
                ].join(' '),
            },
        }

        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => 'root',
            :content_ini => content_ini,
            :mem_limit => mem_limit,
        })

        begin
            systemctl('enable', "#{service_name}.service")

            if service_changed
                warning("Restarting #{service_name}")
                # if unit changes then we need to restart to get new limits working
                systemctl('restart', "#{service_name}.service")
            else
                systemctl('start', "#{service_name}.service")
            end
        rescue Exception => e
            err(e.to_s)
        end
        
        return [service_name]
    end
end
