#
# Copyright 2017 (c) Andrey Galkin
#



class cfweb::appcommon::cid {
    $user = 'futoin'
    $group = 'futoin'
    $home = "/home/${user}"
    $tool_dir = "${cfweb::web_dir}/tools"
    $deploy_callback = "${cfsystem::custombin::bin_dir}/cf_cid_callback"
    $sudoers_file = "/etc/sudoers/${user}"

    $global_futoin_json = {
        env => {
            startup => systemd,
            webServer => nginx,
            externalSetup => "/usr/bin/sudo ${deploy_callback}",
            rvmDir => "${tool_dir}/rvm",
            nvmDir => "${tool_dir}/nvm",
            composerDir => "${tool_dir}/composer",
            flywayDir => "${tool_dir}/flyway",
            liquibaseDir => "${tool_dir}/liquibase",
            sdkmanDir => "${tool_dir}/sdkman",
        }
    }

    $user_futoin_json = {
        env => {
            externalSetup => false
        }
    }

    package { 'python-pip': }
    -> package { 'futoin-cid':
        ensure   => latest,
        provider => pip,
    }
    -> file { '/etc/futoin':
        ensure => directory,
        mode   => '0755',
    }
    -> file { '/etc/futoin.json':
        mode    => '0444',
        content => cfsystem::pretty_json($global_futoin_json),
    }
    -> group { $group:
        ensure => present,
    }
    -> user { $user:
        ensure         => present,
        gid            => $group,
        system         => true,
        shell          => '/bin/bash',
        purge_ssh_keys => true,
    }
    -> file { $home:
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0755',
    }
    -> file { "${home}/futoin.json":
        mode    => '0444',
        content => cfsystem::pretty_json($user_futoin_json),
    }
    -> file { $deploy_callback:
        mode    => '0755',
        content => file('cfweb/_cf_cid_callback'),
    }
    -> file { $tool_dir:
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0755',
    }
    -> cfauth::sudoentry { "grp_${group}":
        user    => "%${group}",
        command => [ $deploy_callback ]
    }
    -> exec { $sudoers_file:
        creates => $sudoers_file,
        command => "/bin/sh -c 'cid sudoers ${user} > ${sudoers_file}'",
    }
    -> file { $sudoers_file:
        mode => '0640',
    }

    # Allow package retrieval
    cfnetwork::client_port { "any:http:${user}":
        user => $user,
    }
    cfnetwork::client_port { "any:https:${user}":
        user => $user,
    }
}