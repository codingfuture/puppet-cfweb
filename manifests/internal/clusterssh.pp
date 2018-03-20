#
# Copyright 2018 (c) Andrey Galkin
#


define cfweb::internal::clusterssh {
    include cfweb
    include cfweb::pki

    $cluster = $cfweb::cluster
    $user = $title

    cfsystem::clusterssh { "cfweb:site:${cluster}:${user}":
        namespace  => 'cfweb:site',
        cluster    => "${cluster}:${user}",
        user       => $user,
        is_primary => !$cfweb::is_secondary,
        key_type   => $cfweb::pki::ssh_key_type,
        key_bits   => $cfweb::pki::ssh_key_bits,
        peer_ipset => $cfweb::cluster_ipset,
    }
}