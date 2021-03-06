#
# Copyright 2016-2019 (c) Andrey Galkin
#


class cfweb (
    String[1] $cluster,
    Boolean $is_secondary = false,
    Array[String[1]] $standalone = [],
    Array[String[1]] $backends = [],
    Array[String[1]] $frontends = [],
    String[1] $web_service = 'cfnginx',
    String[1] $internal_face = 'main',
    Array[String[1]] $cluster_hint = [],
    String[1] $deployuser = 'deployweb',
    Optional[Hash[String[1],Hash]] $deployuser_auth_keys = undef,
) inherits cfweb::global {
    include cfnetwork
    include cfsystem
    include cflogsink

    validate_re($cluster, '^[a-z][a-z0-9_]*$')
    validate_re($web_service, '^[a-z][a-z0-9_]*$')

    $internal_addr = cfnetwork::bind_address($internal_face)
    $web_dir = '/www'
    $acme_challenge_group = 'acme_challenge'
    $acme_challenge_root = "${web_dir}/acme_challenge"

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

    cfweb::internal::clusterhost { $cluster:
        is_secondary => $is_secondary,
    }

    #---
    $cluster_instances = cfsystem::query([
        'from', 'resources', ['extract', [ 'certname', 'parameters' ],
            ['and',
                ['=', 'type', 'Cfweb::Internal::Clusterhost'],
                ['=', 'title', $cluster],
            ],
    ]]).reduce({}) |$memo, $val| {
        $host = $val['certname']
        merge($memo, {
            $host => $val['parameters']
        })
    }

    $cluster_hosts = cfsystem::stable_sort($cluster_instances.keys())
    $is_cluster = size($cluster_hosts) > 1

    $cluster_ipset = "cfweb_${cluster}"
    cfnetwork::ipset { $cluster_ipset:
        type => 'ip',
        addr => cfsystem::stable_sort(unique($cluster_hosts + $cluster_hint)),
    }

    #---
    $primary_host = $cluster_instances.reduce($::trusted['certname']) |$memo, $val| {
        if $val[1]['is_secondary'] {
            $memo
        } else {
            $val[0]
        }
    }

    if $primary_host != $::trusted['certname'] and
        $cfweb::is_secondary != true
    {
        fail([
            "Primary cfweb host for ${cluster} is already known: ${primary_host}.",
            'Please consider setting cfweb::is_secondary'
        ].join("\n"))
    }

    $primary_internal_host = "${internal_face}.${primary_host}"

    # Standalone - public facing
    # NOTE: they still can work in HA cluster
    #---
    $standalone.each |$site_name| {
        $site = $cfweb::global::sites[$site_name]

        if !($site =~ Hash) {
            cf_notify { "cfweb:standalone:${site_name}":
                message  =>"Site '${site_name}' is missing from cfweb::global::sites: ${site}",
                loglevel => 'err',
            }
        } else {
            create_resources(
                    pick($site['type'], 'cfweb::site'),
                    {
                        $site_name => {
                            is_backend => false,
                        }
                    },
                    $site - 'type'
            )
        }
    }


    # Backends - sites which expect proxy_protocol
    # NOTE: must face only load balancer
    #---
    $backends.each |$site_name| {
        $site = $cfweb::global::sites[$site_name]

        if !($site =~ Hash) {
            cf_notify { "cfweb:backends:${site_name}":
                message  =>"Site '${site_name}' is missing from cfweb::global::sites: ${site}",
                loglevel => 'err',
            }
        } else {
            create_resources(
                    pick($site['type'], 'cfweb::site'),
                    {
                        $site_name => {
                            is_backend => true,
                        }
                    },
                    $site - 'type'
            )
        }
    }


    # Frontends - load balancing with proxy_protocol
    #---
    $frontends.each |$site_name| {
        fail('TODO: frontends are not supported yet')
    }
}
