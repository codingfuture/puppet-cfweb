#
# Copyright 2017 (c) Andrey Galkin
#


class cfweb::internal::deployuser {
    $deployuser = $cfweb::deployuser
    $deployuser_auth_keys = $cfweb::deployuser_auth_keys
    $deploy_command = "${cfweb::nginx::bin_dir}/deploy"

    #======================================================================
    group { $deployuser: ensure => present }
    user { $deployuser:
        ensure         => present,
        groups         => ['ssh_access'],
        home           => "/home/${deployuser}",
        managehome     => true,
        purge_ssh_keys => true,
        membership     => inclusive,
        require        => Group['ssh_access'],
    }

    file {"/home/${deployuser}/deployweb.sh":
        owner   => $deployuser,
        group   => $deployuser,
        mode    => '0750',
        content => @("EOT"/$)
        #!/bin/sh
        sudo ${deploy_command} \$1
        |EOT
    }

    cfauth::sudoentry { $deployuser:
        command => $deploy_command,
    }

    if $deployuser_auth_keys {
        create_resources(
            ssh_authorized_key,
            prefix($deployuser_auth_keys, "${deployuser}@"),
            {
                user => $deployuser,
                'type' => 'ssh-rsa',
                require => User[$deployuser],
            }
        )
    }

    #======================================================================
}
