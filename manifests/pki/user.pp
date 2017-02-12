#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::pki::user {
    assert_private()

    $user = $cfweb::pki::ssh_user
    $home_dir = "/home/${user}"

    group { $user:
        ensure => present,
    } ->
    user { $user:
        ensure         => present,
        home           => $home_dir,
        gid            => $user,
        groups         => ['ssh_access'],
        managehome     => true,
        shell          => '/bin/bash',
        purge_ssh_keys => true,
    }

    cfauth::sudoentry { $user:
        command => "/bin/systemctl reload ${cfweb::web_service}.service",
    }

    # Own key
    #---
    cfsystem::clusterssh { "cfweb:${cfweb::cluster}":
        namespace  => 'cfweb',
        cluster    => $cfweb::cluster,
        user       => $user,
        is_primary => !$cfweb::is_secondary,
        key_type   => $cfweb::pki::ssh_key_type,
        key_bits   => $cfweb::pki::ssh_key_bits,
        peer_ipset => $cfweb::cluster_ipset,
    }
}
