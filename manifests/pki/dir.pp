
class cfweb::pki::dir {
    assert_private()
    
    include cfsystem::custombin
    include cfweb::pki::user
    
    $root_dir = $cfweb::pki::root_dir
    $ssh_user = $cfweb::pki::ssh_user
    $cfweb_sync_pki = "${cfsystem::custombin::bin_dir}/cfweb_sync_pki"
    
    #---
    if $cfweb::is_secondary {
        exec { 'cfweb sync PKI':
            user    => $ssh_user,
            command => [
                '/usr/bin/ssh',
                "${ssh_user}@${cfweb::pki::primary_host}",
                $cfweb_sync_pki,
            ].join(' '),
            creates => $root_dir,
            require => User[$ssh_user],
        }
        
        file { $cfweb_sync_pki:
            ensure => absent,
        }
    } else {
        $ticket_dir = $cfweb::pki::ticket_dir
        $vhost_dir = $cfweb::pki::vhost_dir
        
        file { $root_dir:
            ensure => directory,
            owner => $ssh_user,
            group => $ssh_user,
            mode => '0700',
        } ->
        file { $ticket_dir:
            ensure => directory,
            owner => $ssh_user,
            group => $ssh_user,
            mode => '0700',
        } ->
        file { $vhost_dir:
            ensure => directory,
            owner => $ssh_user,
            group => $ssh_user,
            mode => '0700',
        }
        
        #---
        $dhparam = $cfweb::pki::dhparam
        
        exec { 'cfweb DH params':
            command => [
                '/usr/bin/openssl dhparam -rand /dev/urandom',
                '-out', $dhparam,
                $cfweb::pki::dhparam_bits
            ].join(' '),
            creates => $dhparam,
            require => File[$root_dir],
        }
        
        #---
        file { $cfweb_sync_pki:
            owner   => root,
            group   => root,
            mode    => '0755',
            content => epp('cfweb/cfweb_sync_pki.sh.epp', {
                pki_dir => $root_dir,
                ssh_user => $ssh_user,
                hosts => $cfweb::pki::cluster_hosts.reduce([]) |$memo, $v| {
                    $host = $v[0]
                    
                    if $host != $::trusted['certname'] {
                        $memo + $host
                    } else {
                        $memo
                    }
                },
            }),
        }
    }
}
