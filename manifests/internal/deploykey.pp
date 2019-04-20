#
# Copyright 2018-2019 (c) Andrey Galkin
#


define cfweb::internal::deploykey(
    String[1] $key_name
) {
    include cfweb::global

    $user = $title

    ensure_resource( 'cfsystem::sshdir', $user )

    $home = getparam(User[$user], 'home')
    $ssh_dir = "${home}/.ssh"
    $ssh_idkey = "${ssh_dir}/id_deploy"

    $key_info = $cfweb::global::deploy_keys[$key_name]

    if empty($key_info) {
        fail( "Missing \$cfweb::global::deploy_keys[${key_name}]" )
    }

    file { $ssh_idkey:
        owner   => $user,
        group   => $user,
        mode    => '0600',
        content => $key_info['private'],
    }
    -> file { "${ssh_dir}/config_deploy":
        owner   => $user,
        group   => $user,
        mode    => '0600',
        content => [
            "IdentityFile ${ssh_idkey}",
            'ControlMaster auto',
            "ControlPath ${ssh_dir}/%C",
            "ControlPersist 10s",
            ''
        ].join("\n"),
    }
}
