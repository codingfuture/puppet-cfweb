#
# Copyright 2017 (c) Andrey Galkin
#


class cfweb::pki::acme(
    String[1] $installer_url = 'https://raw.githubusercontent.com/Neilpang/acme.sh/master/acme.sh',
    Boolean $staging = false,
) {
    include cfweb::pki::user
    $user = $cfweb::pki::user::user
    $home_dir = $cfweb::pki::user::home_dir

    # Command to use in cert
    #---
    include cfsystem::custombin
    $command = "${cfsystem::custombin::bin_dir}/cfweb_acme_sign"

    file { $command:
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

    $cron_command = [
        "${home_dir}/.acme.sh/acme.sh",
        '--cron',
        '--home',
        "'${home_dir} > /dev/null"
    ]
}
