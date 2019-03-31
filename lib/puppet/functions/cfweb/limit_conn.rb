#
# Copyright 2016-2019 (c) Andrey Galkin
#

Puppet::Functions.create_function(:'cfweb::limit_conn') do
    dispatch :limit_conn do
        param 'String[1]', :site
        param 'String[1]', :name
    end

    def limit_conn(site, name)
        limits = closure_scope["cfweb::nginx::limits"]
        overrides = closure_scope.findresource("Cfweb::Site[#{site}]")['limits']

        return '' if overrides == 'unlimited'

        info = limits.fetch(name, {}).merge(overrides.fetch(name, {}))

        return '' if info['disabled']

        newname = info.fetch('newname', name)
        return "limit_conn #{newname} #{info['count']};"
    end
end
