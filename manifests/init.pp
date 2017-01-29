#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb (
    String[1] $cluster,
    Boolean $is_secondary = false,
    Array[String] $standalone = [],
    Array[String] $backends = [],
    Array[String] $frontends = [],
    String[1] $web_service = 'cfnginx',
    String[1] $internal_face = 'main',
) inherits cfweb::global {
    include cfnetwork

    validate_re($cluster, '^[a-z][a-z0-9_]*$')
    validate_re($web_service, '^[a-z][a-z0-9_]*$')

    $internal_addr = cf_get_iface_address(Cfnetwork::Iface[$internal_face])[0]

    if !$internal_addr {
        fail('$cfweb::internal_face must be set to interface with valid address')
    }

    cfsystem_info { 'cfweb':
        ensure => present,
        info   => {
            cluster      => $cluster,
            is_secondary => $is_secondary,
            web_service  => $web_service,
        }
    }

    #---
    $host_facts = cf_query_facts("cfweb.cluster=\"${cluster}\"", ['cfweb'])
    $cluster_hosts = $host_facts.reduce({}) |$memo, $val| {
        $host = $val[0]
        $cluster_info = $val[1]['cfweb']
        merge($memo, {
            $host => $cluster_info
        })
    }

    $primary_host = $cluster_hosts.reduce('') |$memo, $val| {
        if $val[1]['is_secondary'] {
            $memo
        } else {
            $val[0]
        }
    }

    if $primary_host != '' and
        $primary_host != $::trusted['certname'] and
        $cfweb::is_secondary != true
    {
        fail([
            "Primary cfweb host for ${cluster} is already known: ${primary_host}.",
            'Please consider setting cfweb::is_secondary'
        ].join("\n"))
    }

    # Standalone - public facing
    # NOTE: they still can work in HA cluster
    #---
    $standalone.each |$site_name| {
        $site = $cfweb::global::sites[$site_name]

        if !($site =~ Hash) {
            fail("Site '${site_name}' is missing from cfweb::global::sites: ${site}")
        }

        create_resources(
                'cfweb::site',
                {
                    $site_name => {
                        is_backend => false,
                    }
                },
                $site
        )
    }


    # Backends - sites which expect proxy_protocol
    # NOTE: must face only load balancer
    #---
    $backends.each |$site_name| {
        $site = $cfweb::global::sites[$site_name]

        if !($site =~ Hash) {
            fail("Site '${site_name}' is missing from cfweb::global::sites: ${site}")
        }

        create_resources(
                'cfweb::site',
                {
                    $site_name => {
                        is_backend => true,
                    }
                },
                $site
        )
    }


    # Frontends - load balancing with proxy_protocol
    #---
    $frontends.each |$site_name| {
        fail('TODO: frontends are not supported yet')
    }
}
