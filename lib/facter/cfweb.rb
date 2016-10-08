require 'json'

# Done this way due to some weird behavior in tests also ignoring $LOAD_PATH
begin
    require File.expand_path( '../../puppet_x/cf_system', __FILE__ )
rescue LoadError
    require File.expand_path( '../../../../cfsystem/lib/puppet_x/cf_system', __FILE__ )
end

Facter.add('cfweb') do
    setcode do
        cfsystem_json = PuppetX::CfSystem::CFSYSTEM_CONFIG
        begin
            json = File.read(cfsystem_json)
            json = JSON.parse(json)
            sections = json['sections']
            persistent = json['persistent']
            
            # Generic
            #---
            ret = sections['info']['cfweb'].clone
            
            # PKI
            #---
            begin
                cfwebpki = sections['info']['cfwebpki']
                home_dir = cfwebpki['home']
                user = cfwebpki['user']
                ssh_dir = "#{home_dir}/.ssh"
                
                ret['ssh_keys'] = Dir.glob("#{ssh_dir}/id_*.pub").reduce({}) do |memo, f|
                    keycomp = File.read(f).split(/\s+/)
                    
                    if keycomp.size >= 2
                        s = File.basename(f)
                        memo[s] = {
                            'user' => user,
                            'type' => keycomp[0],
                            'key'  => keycomp[1],
                        }
                    end
                    memo
                end
            rescue
            end
            
            # Vhosts
            #---
            sites = {}
            cfwebconn = persistent.fetch('cfwebconn', {})
            
            sections.fetch('cf30web2_app', {}).each do |k, info|
                site = info['site']
                type = info['type']
                maxconn = cfwebconn.fetch(site, {}).fetch(type, 0)
                
                sites[site] ||= {
                    'apps' => {},
                    'maxconn' => 0,
                }
                site_info = sites[site]
                site_info['maxconn'] += maxconn
                
                site_info['apps'][type] = {
                    maxconn => cfwebconn.fetch(site, {}).fetch(type, 0)
                }
            end
            
            ret['sites'] = sites
            
            #---
            ret
        rescue => e
            nil
            #e
        end
    end 
end
