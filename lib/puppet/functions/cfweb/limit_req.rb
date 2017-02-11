#
# Copyright 2016-2017 (c) Andrey Galkin
#


Puppet::Functions.create_function(:'cfweb::limit_req') do
    dispatch :limit_req do
        param 'String[1]', :site
        param 'String[1]', :name
    end
    
    def limit_req(site, name)
        limits = closure_scope["cfweb::nginx::limits"]
        overrides = closure_scope.findresource("Cfweb::Site[#{site}]")['limits']
        
        info = limits.fetch(name, {}).merge(overrides.fetch(name, {}))
        
        return '' if info['disabled']

        newname = info.fetch('newname', name)
        res = "limit_req zone=#{newname}"
    
        burst = info['burst']
        res += " burst=#{burst}" if burst
        
        res += " nodelay" if info['nodelay']

        res += ';'
        return res
    end
end
