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
        run_symlink = "#{site_dir}/.run"
        
        begin
            File.lstat(run_symlink)
        rescue
            File.symlink(run_dir, run_symlink)
        end
        
        #---
        
        warning("CID deploy: #{site_dir}")
        Puppet::Util::Execution.execute(
            [
                '/usr/bin/sudo',
                '-u', "deploy_#{user}",
                '-H',
                '/usr/local/bin/cid',
                '--',
                "deploy #{deploy_args}",
                "--#{url_arg}=#{url}",
                "--limit-memory=#{mem_limit}M",
                "--deployDir=#{site_dir}",
            ]
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
                'ExecStart' => 'cid service master',
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
