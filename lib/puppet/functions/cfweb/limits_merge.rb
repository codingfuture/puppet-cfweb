#
# Copyright 2016-2018 (c) Andrey Galkin
#


Puppet::Functions.create_function(:'cfweb::limits_merge') do
    dispatch :limits_merge do
        param 'String[1]', :site
    end
    
    def limits_merge(site)
        limits = closure_scope["cfweb::nginx::limits"]
        overrides = closure_scope.findresource("Cfweb::Site[#{site}]")['limits']
        
        res = limits.clone

        res.each do |n, v|
            res[n] = v.merge(overrides.fetch(n, {}))
        end
        
        overrides.each do |n, v|
            if res[n].nil?
                res[n] = v.clone
            end
        end
        
        res.each do |n, info|
            newname = info.fetch('newname', n)
            lim_type = info['type'].to_s
            
            if info['disabled']
                expr = ''
            elsif lim_type == 'req'
                expr = "limit_req zone=#{newname}"
            
                burst = info['burst']
                expr += " burst=#{burst}" if burst
                
                expr += " nodelay" if info['nodelay']

                expr += ';'
            elsif lim_type == 'conn'
                expr = "limit_conn #{newname} #{info['count']};"
            else
                fail("Unknown limit type '#{lim_type}': #{n}=>#{info}")
            end
            
            info['expr'] = expr
        end
        
        return res
    end
end
