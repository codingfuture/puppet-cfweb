#
# Copyright 2016-2019 (c) Andrey Galkin
#


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
            $default_certs.dig($iface, $port),
            $default_certs.dig($iface),
            $default_certs.dig('any', $port),
            $default_certs.dig('any'),
            'default'
        )).map |$cert_name| {
            cfweb::certinfo($cert_name)
        }
    } else {
        $certs = []
    }

    $listen = $iface ? {
        'any' => '*',
        default => cfnetwork::bind_address($iface),
    }

    if !$listen {
        fail("Interface ${iface} must have static address configured!")
    }

    $trusted_proxy = $is_backend ? {
        true => any2array($cfweb::nginx::trusted_proxy),
        default => undef
    }

    file { "${sites_dir}/default__${iface}_${port}.conf":
        mode    => '0640',
        content => epp('cfweb/default_vhost.epp', {
            listen         => $listen,
            port           => $port,
            backlog        => pick($cfweb::nginx::backlog),
            tls            => $tls,
            proxy_protocol => $is_backend,
            trusted_proxy  => pick($trusted_proxy, []),
            certs          => $certs,
        }),
        notify  => Exec['cfweb_reload'],
    }

    $fw_service = "cfweb${port}"
    ensure_resource(
        'cfnetwork::describe_service',
        $fw_service,
        { server => "tcp/${port}" }
    )
    ensure_resource(
        'cfnetwork::service_port',
        "${iface}:${fw_service}",
        { src => $trusted_proxy }
    )

    # Allow local root access for testing purposes
    #---
    ensure_resource(
        'cfnetwork::service_port',
        "local:${fw_service}",
        { src => $trusted_proxy }
    )
    ensure_resource(
        'cfnetwork::client_port',
        "local:${fw_service}",
        { user => 'root' }
    )
}
