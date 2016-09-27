
define cfweb::site (
    $server_name,
    $alt_names = [],
    $redirect_alt_names = true,
    
    $ifaces = ['main'],
    $plain_ports = [80],
    $tls_ports = [443],
    $redirect_plain = true,
    
    $is_backend = false,
    
    $auto_cert = {},
    $shared_certs = [],
    $dbaccess = {},
    $apps = {},
    
    $memory_weight = 100,
    $memory_max = undef,
    $cpu_weight = 100,
    $io_weight = 100,
) {
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
    $user = $is_dynamic ? {
        true => $site,
        default => $cfweb::nginx::user
    }
    
    $site_dir = "${cfweb::nginx::web_dir}/${site}"
    $bin_dir = "${site_dir}/bin"
    $persistent_dir = "${cfweb::nginx::persistent_dir}/${site}"
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
        }
    }
    
    file { [$site_dir, $bin_dir, $persistent_dir]:
        ensure  => directory,
        mode    => '0750',
        owner   => $user,
        group   => $user,
        require => User[$user],
    }
        
    
    # DB access
    #---
    # global site DB access not tied to sub-app
    # should be avoided in general due to manual
    # $max_connections configuration
    if $is_dynamic and $dbaccess {
        $dbaccess.each |$da| {
            create_resources(
                'cfdb::access',
                { local_user => $user },
                $da
            )
        }
    }

    # Define apps
    #---
    if $is_dynamic {
        cfsystem_memory_weight { $site:
            ensure => present,
            weight => $memory_weight,
            max_mb => $memory_max,
        }
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
            default => regsubst(getparam(Cfnetwork::Iface[$iface], 'address'), '/[0-9]+', ''),
        }
    }
    
    $trusted_proxy = $is_backend ? {
        true => any2array($cfweb::nginx::trusted_proxy),
        default => undef
    }

    file { "${cfweb::nginx::sites_dir}/${site}.conf":
        mode    => '0640',
        content => epp('cfweb/app_vhost.epp', {
            site  => $site,
            
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
            apps => $apps,
        }),
        notify => Service[$cfweb::nginx::service_name]
    }
}
