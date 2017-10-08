#
# Copyright 2016-2017 (c) Andrey Galkin
#

require 'json'

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
        Puppet::Util::Execution.execute(
            [
                '/usr/bin/sudo',
                '-u', user,
                '-H',
                '/usr/local/bin/cid',
                'deploy',
            ] + deploy_args
        )
        
        #---
        futoin_conf = File.read("#{site_dir}/futoin.json")
        futoin_conf = JSON.parse(futoin_conf)
        
        #---
        saveMaxConn(site, type, 3)

        # Service
        #---

        content_ini = {
            'Unit' => {
                'Description' => "CFWEB FutoIn #{site}",
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
