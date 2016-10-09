
define cfweb::site (
    String $server_name,
    Array[String] $alt_names = [],
    Boolean $redirect_alt_names = true,
    
    Array[String] $ifaces = ['main'],
    Array[Integer] $plain_ports = [80],
    Array[Integer] $tls_ports = [443],
    Boolean $redirect_plain = true,
    
    Boolean $is_backend = false,
    
    Hash[String,Hash] $auto_cert = {},
    Array[String] $shared_certs = [],
    Hash[String,Hash] $dbaccess = {},
    Hash[String,Hash,1] $apps = { 'static' => {} },
    Optional[String] $custom_conf = undef,
    String $web_root = '/',
    
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,    
    
    Hash[String, Struct[{
        type       => Enum['conn', 'req'],
        var        => String[1],
        count      => Optional[Integer[1]],
        entry_size => Optional[Integer[1]],
        rate       => Optional[String[1]],
        burst      => Optional[Integer[0]],
        nodelay    => Optional[Boolean],
        newname    => Optional[String[1]],
    }]] $limits = {},
    
    Optional[Hash[String, Hash]] $deploy = undef,
    Optional[String[1]] $force_user = undef,
) {
    include cfdb
    include cfweb::nginx
    
    validate_re($title, '^[a-z][a-z0-9_]*$')
    
    #---
    if !$shared_certs and size($tls_ports) > 0 {
        $auto_cert_name = "auto__${server_name}"
        create_resources(
            'cfweb::pki::cert',
            {
                $auto_cert_name => {
                    'cert_name' => $server_name,
                }
            },
            $auto_cert
        )
        $dep_certs = [$auto_cert_name]
    } elsif $shared_certs {
        $shared_certs.each |$v| {
            if !defined(Cfweb::Pki::Cert[$v]) {
                fail("Please make sure Cfweb::Pki::Cert[$v] is defined for use in ${title}")
            }
        }
        $dep_certs = $shared_certs
    }
    
    # Default hosts configure listen socket
    #---
    $ifaces.each |$iface| {
        $plain = $plain_ports.each |$port| {
            ensure_resource('cfweb::nginx::defaulthost', "${iface}:${port}", {
                iface      => $iface,
                port       => $port,
                tls        => false,
                is_backend => $is_backend,
            })
        }
        $tls = $tls_ports.each |$port| {
            ensure_resource('cfweb::nginx::defaulthost', "${iface}:${port}", {
                iface      => $iface,
                port       => $port,
                tls        => true,
                is_backend => $is_backend,
                require    => Cfweb::Pki::Cert[$dep_certs],
            })
        }
    }
    
    # Basic file structure
    #---
    $site = "app_${title}"
    $is_dynamic = (size(keys($apps) - ['static']) > 0)
    $user = $force_user ? {
        undef => $is_dynamic ? {
            true => $site,
            default => $cfweb::nginx::user
        },
        default => $force_user,
    }
    
    $site_dir = "${cfweb::nginx::web_dir}/${site}"
    $tmp_dir = "${site_dir}/tmp"
    $persistent_dir = "${cfweb::nginx::persistent_dir}/${site}"
    $conf_prefix = "${cfweb::nginx::sites_dir}/${site}"
    # This must be created by deploy script
    $document_root = "${site_dir}/current"
    
    if $is_dynamic {
        group { $user:
            ensure => present,
        } ->
        user { $user:
            ensure => present,
            gid => $user,
            home => $site_dir,
            require => Group[$user],
        } ->
        exec { "add_nginx_to_${user}":
            command => "/usr/sbin/adduser ${cfweb::nginx::user} ${user} && \
            /usr/sbin/service ${cfweb::nginx::service_name} reload",
            unless => "/usr/bin/id -Gn ${cfweb::nginx::user} | /bin/grep -q ${user}",
        } ->
        file { [
                "${cfweb::nginx::bin_dir}/start-${title}",
                "${cfweb::nginx::bin_dir}/stop-${title}",
                "${cfweb::nginx::bin_dir}/restart-${title}",
                "${cfweb::nginx::bin_dir}/reload-${title}",
            ]:
            ensure => link,
            target => "${cfweb::nginx::generic_control}"
        }
    }
    
    file { $site_dir:
        ensure  => directory,
        mode    => '0750',
        owner   => $user,
        group   => $user,
        require => User[$user],
    }

    file { $document_root:
        ensure  => link,
        replace => false,
        target  => $cfweb::nginx::empty_root,
    }

    
    # DB access
    #---
    if $is_dynamic and $dbaccess {
        $dbaccess_deps = ($dbaccess.map |$k, $da| {
            $name = "${title}:${k}"
            create_resources(
                'cfdb::access',
                { $name => {
                    local_user    => $user,
                    custom_config => 'cfweb::appcommon::dbaccess',
                } },
                merge({
                    max_connections => try_get_value(
                        $::facts,
                        "cfweb/sites/${site}/maxconn",
                        $cfdb::max_connections_default
                    )
                }, $da)
            )
            $name
        })
        
        
        $dbaccess_app_deps = ($apps.reduce({}) |$memo, $v| {
            $app = $v[0]
            $app_info = $v[1]
            $app_type = split($app, ':')[-1]
                
            $names = pick($app_info['dbaccess'], {}).map |$k, $da| {
                    $name = "${title}-${app_type}:${k}"
                    create_resources(
                        'cfdb::access',
                        { $name => {
                            local_user    => $user,
                            custom_config => 'cfweb::appcommon::dbaccess',
                        } },
                        merge({
                            max_connections => try_get_value(
                                $::facts,
                                "cfweb/sites/${site}/apps/${app_type}/maxconn",
                                $cfdb::max_connections_default
                            )
                        }, $da)
                    )
                    $name
                }
                
            merge($memo, { $app => $names })
        })
    } else {
        $dbaccess_deps = []
        $dbaccess_app_deps = {}
    }

    # Define apps
    #---
    $cfg_notify = [
        Service[$cfweb::nginx::service_name],
    ]
    
    if $is_dynamic {
        file { [$persistent_dir, $tmp_dir]:
            ensure  => directory,
            mode    => '0750',
            owner   => $user,
            group   => $user,
            require => User[$user],
        }
    
        # Define global app slice
        cfweb_app { $user:
            ensure        => present,
            type          => 'global',
            site          => $title,
            user          => $user,
            site_dir      => $site_dir,
            
            cpu_weight    => $cpu_weight,
            io_weight     => $io_weight,
            
            misc          => {},
        }
    }
        
    $apps.each |$app, $app_info| {
        $puppet_type = size(split($app, ':')) ? {
            1       => "cfweb::app::${app}",
            default => $app,
        }
        
        $app_dbaccess_deps = $dbaccess_deps +
                pick($dbaccess_app_deps[$app], [])
        
        create_resources(
            $puppet_type,
            {
                $title => {
                    site           => $title,
                    user           => $user,
                    site_dir       => $site_dir,
                    conf_prefix    => $conf_prefix,
                    type           => split($app, ':')[-1],
                    dbaccess_names => $app_dbaccess_deps,
                    require        =>
                        Cfweb::Appcommon::Dbaccess[$app_dbaccess_deps],
                    notify         => $cfg_notify,
                },
            },
            $app_info
        )
    }
    
    # Create vhost file
    #---
    if size($dep_certs) {
        include cfweb::pki
        
        $certs = $dep_certs.map |$cert_name| {
            getparam(Cfweb::Pki::Certinfo[$cert_name], 'info')
        }
    } else {
        $certs = []
    }
    
    $bind = $ifaces.map |$iface| {
        $iface ? {
            'any' => '*',
            default => split(getparam(Cfnetwork::Iface[$iface], 'address'), '/')[0],
        }
    }
    
    $trusted_proxy = $is_backend ? {
        true => any2array($cfweb::nginx::trusted_proxy),
        default => undef
    }

    file { "${conf_prefix}.conf":
        mode    => '0640',
        content => epp('cfweb/app_vhost.epp', {
            site  => $title,
            conf_prefix => $conf_prefix,
            
            server_name => $server_name,
            alt_names => $alt_names,
            redirect_alt_names => $redirect_alt_names,
            bind => $bind,
            plain_ports => $plain_ports,
            tls_ports => $tls_ports,
            redirect_plain => $redirect_plain,
            proxy_protocol => $is_backend,
            trusted_proxy => $trusted_proxy,
            
            certs => $certs,
            apps => keys($apps),
                       
            custom_conf => pick_default($custom_conf, ''),
        }),
        notify => $cfg_notify,
    }
    
    # Deploy procedure
    #---
    if $deploy {
        create_resources(
            'cfweb::deploy',
            {
                site     => $title,
                user     => $user,
                site_dir => $site_dir,
                apps     => keys($apps),
                # Note: it must run AFTER the rest is configured
                require  => $cfg_notify,
            },
            $deploy
        )
    }
}
