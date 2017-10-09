#
# Copyright 2016-2017 (c) Andrey Galkin
#

require 'json'
require 'shellwords'

module PuppetX::CfWeb::Futoin::App
    include PuppetX::CfWeb::Futoin
    
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
                    "--limit-memory=#{mem_limit}M",
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
        futoin_conf = File.read("#{site_dir}/futoin.json")
        futoin_conf = JSON.parse(futoin_conf)
        
        #---
        saveMaxConn(site, type, 3)

        # Service
        #---

        content_ini = {
            'Unit' => {
                'Description' => "CFWEB App: #{site}",
            },
            'Service' => {
                'LimitNOFILE' => 'infinity',
                'WorkingDirectory' => "#{site_dir}",
                'Slice' => "#{PuppetX::CfWeb::SLICE_PREFIX}#{user}.slice",
                'ExecStart' => '/usr/local/bin/cid service master',
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
