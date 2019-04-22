#
# Copyright 2019 (c) Andrey Galkin
#


class cfweb::appcommon::docker (
    Optional[String[1]]
        $worker_token = undef,
    Hash
        $docker_options = {},
){
    class { 'cfweb::internal::dockerbase':
        stage   => setup,
        options => $docker_options + {
            iptables => false,
        },
    }

    include cfweb

    $dockerfile_dir = "${cfweb::web_dir}/docker"
    $is_manager = !$cfweb::is_secondary

    file { $dockerfile_dir:
        ensure => directory,
        mode   => '0700',
    }

    # Default configuration
    # ---
    Docker::Image {
        ensure => absent,
    }

    if $is_manager {
        Docker_network {
            ensure => absent,
        }
        Docker::Swarm {
            ensure => absent,
        }
        Docker::Services {
            ensure => absent,
        }
    }

    # Swarm cluster
    # ---
    cfnetwork::describe_service { 'docker_swarm':
        server => [
            'tcp/2377',
            'tcp/7946',
            'udp/7946',
            'udp/4789',
        ],
    }

    if $is_manager {
        # TODO: Puppet-based PKI
        docker::swarm { $cfweb::cluster:
            ensure         => present,
            init           => true,
            advertise_addr => $cfweb::internal_addr,
            listen_addr    => $cfweb::internal_addr,
        }
    } elsif !empty($worker_token) {
        # TODO: Puppet-based PKI / automatic join token retrieval
        docker::swarm { $cfweb::cluster:
            ensure         => present,
            init           => false,
            advertise_addr => $cfweb::internal_addr,
            listen_addr    => $cfweb::internal_addr,
            manager_ip     => $cfweb::primary_internal_host,
            token          => $worker_token,
        }
    } else {
        fail("Please manually set \$worker_token for secondary nodes for now.\nUse 'docker swarm join-token'")
    }

    # Firewall integration
    # ---
    if ! $cfnetwork::is_router {
        fail("Docker requires \$cfnetwork::is_router=true")
    }

    if ! $cfnetwork::sysctl::enable_bridge_filter {
        fail("Docker requires \$cfnetwork::sysctl::enable_bridge_filter=true")
    }

    # Just make firewall aware of such interface
    cfnetwork::iface { 'docker':
        device          => 'docker_gwbridge',
        debian_template => 'cfweb/docker_gwbridge_iface',
        address         => '172.18.0.1/16',
    }

    # allow docker-proxy
    cfnetwork::client_port { 'docker:allports:root':
        user => root,
    }
    cfnetwork::router_port { 'docker/any:dns': }
}
