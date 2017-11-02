#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::pki::dir {
    assert_private()

    include cfsystem::custombin
    require cfweb::pki::user

    $root_dir = $cfweb::pki::root_dir
    $ssh_user = $cfweb::pki::ssh_user
    $cfweb_sync_pki = "${cfsystem::custombin::bin_dir}/cfweb_sync_pki"
    $cfweb_update_tls_ticket = "${cfsystem::custombin::bin_dir}/cfweb_update_tls_ticket"

    #---
    ensure_packages(['rsync'])

    if $cfweb::is_secondary {
        if !($cfweb::primary_host =~ String[1]) {
            fail('Primary host is not known')
        }

        exec { 'cfweb_sync_pki_init':
            user    => $ssh_user,
            command => [
                '/usr/bin/ssh',
                "${ssh_user}@${cfweb::primary_host}",
                $cfweb_sync_pki,
            ].join(' '),
            creates => $root_dir,
            require => [
                User[$ssh_user],
                Cfsystem::Clusterssh["cfweb:${cfweb::cluster}"],
                Anchor['cfnetwork:firewall'],
                Package['rsync'],
            ]
        }
        -> exec { 'cfweb_sync_pki':
            user        => $ssh_user,
            command     => [
                '/usr/bin/ssh',
                "${ssh_user}@${cfweb::primary_host}",
                $cfweb_sync_pki,
            ].join(' '),
            refreshonly => true,
        }

        file { $cfweb_sync_pki:
            ensure => absent,
        }

        file { $cfweb_update_tls_ticket:
            ensure => absent,
        }
    } else {
        $ticket_dir = $cfweb::pki::ticket_dir
        $key_dir = $cfweb::pki::key_dir
        $cert_dir = $cfweb::pki::cert_dir

        file { $root_dir:
            ensure => directory,
            owner  => $ssh_user,
            group  => $ssh_user,
            mode   => '0700',
        }
        -> file { $ticket_dir:
            ensure => directory,
            owner  => $ssh_user,
            group  => $ssh_user,
            mode   => '0700',
        }
        -> file { $key_dir:
            ensure => directory,
            owner  => $ssh_user,
            group  => $ssh_user,
            mode   => '0700',
        }
        -> file { $cert_dir:
            ensure => directory,
            owner  => $ssh_user,
            group  => $ssh_user,
            mode   => '0700',
        }

        #---
        require cfsystem::randomfeed
        $dhparam = $cfweb::pki::dhparam

        exec {'Generating CF Web Diffie-Hellman params...':
            command  => '/bin/true',
            creates  => $dhparam,
            loglevel => 'warning',
        }
        ~> exec {'cfweb_dhparam':
            command     => [
                "${cfweb::pki::openssl} dhparam -rand /dev/urandom",
                '-out', $dhparam,
                $cfweb::pki::dhparam_bits
            ].join(' '),
            refreshonly => true,
            require     => File[$root_dir],
        }

        #---
        file { $cfweb_sync_pki:
            owner   => root,
            group   => root,
            mode    => '0755',
            content => epp('cfweb/cfweb_sync_pki.sh.epp', {
                pki_dir     => $root_dir,
                acme_dir    => $cfweb::acme_challenge_root,
                ssh_user    => $ssh_user,
                hosts       => $cfweb::cluster_hosts - $::trusted['certname'],
                web_service => $cfweb::web_service,
            }),
        }

        #---
        if $cfweb::pki::tls_ticket_key_count < 2 {
            fail('$cfweb::pki::tls_ticket_key_count must be at least 2')
        }

        file { $cfweb_update_tls_ticket:
            owner   => root,
            group   => root,
            mode    => '0700',
            content => epp('cfweb/cfweb_update_tls_ticket.sh.epp', {
                ticket_dir     => $ticket_dir,
                user           => $ssh_user,
                cfweb_sync_pki => $cfweb_sync_pki,
                old_age        => $cfweb::pki::tls_ticket_key_age,
                key_count      => $cfweb::pki::tls_ticket_key_count,
                web_service    => $cfweb::web_service,
                openssl        => $cfweb::pki::openssl,
            }),
        }

        create_resources( 'cron', {
            cfweb_update_tls_ticket => merge( $cfweb::pki::tls_ticket_cron, {
                command => $cfweb_update_tls_ticket,
            })
        })

        exec { 'cfweb_update_tls_ticket':
            command => $cfweb_update_tls_ticket,
            creates => [
                "${ticket_dir}/ticket1.key",
                "${ticket_dir}/ticket2.key",
            ],
            require => [
                File[$ticket_dir],
                File[$cfweb_update_tls_ticket],
                Anchor['cfnetwork:firewall'],
                Package['rsync'],
            ],
        }

        #---
        exec { 'cfweb_sync_pki':
            user        => $ssh_user,
            command     => $cfweb_sync_pki,
            refreshonly => true,
            require     => [
                User[$ssh_user],
                Anchor['cfnetwork:firewall'],
            ],
            notify      => Exec['cfweb_reload'],
        }
    }
}
