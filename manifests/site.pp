
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
        $plain_ports.each |$port| {
            ensure_resource('cfweb::nginx::defaulthost', "${iface}:${port}", {
                iface      => $iface,
                port       => $port,
                tls        => false,
                is_backend => $is_backend,
            })
        }
        $tls_ports.each |$port| {
            ensure_resource('cfweb::nginx::defaulthost', "${iface}:${port}", {
                iface      => $iface,
                port       => $port,
                tls        => true,
                is_backend => $is_backend,
                require    => Cfweb::Pki::Cert[$dep_certs],
            })
        }
    }
    
    # DB access
    #---

    # Define vhost
    #---
    if size(keys($apps) - ['static']) > 0 {
        cfsystem_memory_weight { "cfweb-${title}":
            ensure => present,
            weight => $memory_weight,
            max_mb => $memory_max,
        }
    }
}
