module Puppet::Parser::Functions
    newfunction(:cf_nginx_limit_req,  :type => :rvalue, :arity => 2) do |args|
        site = args[0]
        name = args[1]
        
        limits = self.lookupvar("cfweb::nginx::limits")
        overrides = findresource("Cfweb::Site[#{site}]")['limits']
        
        info = limits.fetch(name, {}).merge(overrides.fetch(name, {}))
        
        if info['disabled']
            ''
        else
            newname = info.fetch('newname', name)
            res = "limit_req #{newname}"
        
            burst = info['burst']
            res += " burst=#{burst}" if burst
            
            res += " nodelay" if info['nodelay']

            res += ';'
            res
        end
    end
end