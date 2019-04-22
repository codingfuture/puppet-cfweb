#
# Copyright 2017-2019 (c) Andrey Galkin
#


class cfweb::pki::acme(
    String[1] $installer_url = 'https://raw.githubusercontent.com/Neilpang/acme.sh/master/acme.sh',
    Boolean $staging = false,
) {
    include cfweb::pki::user
    $user = $cfweb::pki::user::user
    $home_dir = $cfweb::pki::user::home_dir

    $command_ensure = $cfweb::is_secondary ? {
        true => absent,
        default => present,
    }

    # Command to use in cert
    #---
    include cfsystem::custombin
    $command = "${cfsystem::custombin::bin_dir}/cfweb_acme_sign"

    file { $command:
        ensure  => $command_ensure,
        mode    => '0500',
        content => epp('cfweb/cfweb_acme_sign.epp'),
    }

    # ACME requests
    #---
    cfnetwork::client_port { "any:https:${user}-acme":
        user => $user,
    }

    # ACME setup
    #---
    ensure_packages(['curl'])

    $curl_opts = [
        '--connect-timeout 10',
        '--silent',
        '--fail',
    ].join(' ')

    $installer_opts = [
        '--install',
        '--nocron',
        '--webroot', $cfweb::acme_challenge_root,
    ].join(' ')

    exec { 'ACME setup':
        command     => [
            "/usr/bin/curl ${curl_opts} '${installer_url}'",
            "/bin/bash -s -- ${installer_opts}",
        ].join(' | '),
        creates     => "${home_dir}/.acme.sh/acme.sh",
        user        => $user,
        group       => $user,
        cwd         => $home_dir,
        environment => [
            "HOME=${home_dir}",
            'INSTALLONLINE=1',
        ],
        logoutput   => true,
    }
    -> Anchor['cfweb::pki:dyn_setup']

    # ACME cron
    #---
    $cron_command = "${cfsystem::custombin::bin_dir}/cfweb_acme_cron"

    file { $cron_command:
        ensure  => $command_ensure,
        mode    => '0500',
        content => epp('cfweb/cfweb_acme_cron.epp'),
    }
    cron { 'ACME update':
        ensure  => $command_ensure,
        command => $cron_command,
        hour    => '12',
        minute  => '30',
        weekday => '1-3', # Mon through Wed
    }

    ensure_resource('file', '/etc/cron.deny', {
        mode    => '640',
        replace => false,
        content => '',
    })

    file_line { 'Deny cfwebpki cron':
        ensure  => absent,
        path    => '/etc/cron.deny',
        line    => $user,
        require => File['/etc/cron.deny'],
    }

    # Ensure default host
    #---
    if $cfweb::is_secondary {
        include cfweb::nginx

        $web_user = $cfweb::nginx::user

        cfnetwork::client_port { "any:http:${web_user}-acme":
            user => $web_user,
            dst  => $cfweb::primary_host
        }
    } else {
        ensure_resource('cfweb::nginx::defaulthost', 'main:80', {
            iface          => 'main',
            port           => 80,
            tls            => false,
            is_backend     => false,
            proxy_protocol => false,
        })
    }
}
