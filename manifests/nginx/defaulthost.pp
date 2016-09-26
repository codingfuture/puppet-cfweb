
define cfweb::nginx::defaulthost (
    $iface,
    $port,
    $tls,
    $is_backend,
) {
    assert_private()
    include cfweb::nginx
    
    $sites_dir = $cfweb::nginx::sites_dir
    $default_certs = $cfweb::nginx::default_certs

    if $tls {
        include cfweb::pki
        
        $certs = any2array(pick(
            try_get_value($default_certs, "${iface}/${port}"),
            try_get_value($default_certs, "${iface}"),
            try_get_value($default_certs, "any/${port}"),
            try_get_value($default_certs, "any"),
            'default'
        )).map |$cert_name| {
            $key_name = pick(
                    getparam(Cfweb::Pki::Cert[$cert_name], 'key_name'),
                    $cfweb::pki::key_name
            )
            
            $key_file = "${cfweb::pki::key_dir}/${key_name}.key"
            $crt_file = "${cfweb::pki::cert_dir}/${cert_name}.crt"
            
            $cert_source = pick_default(
                    getparam(Cfweb::Pki::Cert[$cert_name], 'cert_source'),
                    $cfweb::pki::cert_source
            )

            if $cert_source and $cert_source != '' {
                $trusted_file = "${crt_file}.trusted"
            } else {
                $trusted_file = undef
            };
            
            # PUP-4464
            ({
                cert_name    => $cert_name,
                key_file     => $key_file,
                crt_file     => $crt_file,
                trusted_file => $trusted_file,
            })
        }
    } else {
        $certs = []
    }
    
    $listen = $iface ? {
        'any' => '*',
        default => regsubst(getparam(Cfnetwork::Iface[$iface], 'address'), '/[0-9]+', ''),
    }
    
    if !$listen {
        fail("Interface ${iface} must have static address configured!")
    }
    
    $trusted_proxy = $is_backend ? {
        true => any2array($cfweb::nginx::trusted_proxy),
        default => undef
    }
    
    file { "${sites_dir}/default__${iface}_${port}.conf":
        mode => '640',
        content => epp('cfweb/default_vhost.epp', {
            listen         => $listen,
            port           => $port,
            backlog        => pick($cfweb::nginx::backlog),
            tls            => $tls,
            proxy_protocol => $is_backend,
            trusted_proxy  => pick($trusted_proxy, []),
            certs          => $certs,
        }),
        notify => Service[$cfweb::nginx::service_name]
    }
    
    $fw_service = "cfweb${port}"
    ensure_resource(
        'cfnetwork::describe_service',
        $fw_service,
        { server => "tcp/${port}" }
    )
    cfnetwork::service_port { "${iface}:${fw_service}":
        src => $trusted_proxy
    }
}