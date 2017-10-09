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
        deploy_conf = conf[:misc]
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
                
                File.open(custom_script_file, 'w+', 0700 ) do |f|
                    f.write(custom_script)
                end
                
                FileUtils.chown(user, user, custom_script_file)
                
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
            
            File.open('.deploy.log', 'w+', 0600 ) do |f|
                f.write(res)
            end
            
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
        
        # Services
        #---
        service_names = []
        
        futoin_conf['deploy']['autoServices'].each do |name, instances|
            info = futoin_conf['entryPoints'][name]
            
            if info['tool'] == 'nginx'
                # TODO: update global nginx config
            end
            
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
