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
            
            # Generic
            #---
            ret = sections['info']['cfweb']
            
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
            # TODO
            
            #---
            ret
        rescue => e
            nil
            #e
        end
    end 
end
