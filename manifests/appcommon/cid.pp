#
# Copyright 2017 (c) Andrey Galkin
#



class cfweb::appcommon::cid {
    $user = 'futoincid'
    $group = 'futoin'
    $home = "${cfweb::web_dir}/${user}"

    $global_futoin_json = {
        env => {
            startup => systemd,
            webServer => nginx,
            externalSetup => {
                webServer    => true,
                startup      => true,
                installTools => true,
            }
        }
    }

    $user_futoin_json = {
        env => {
            externalSetup => merge($global_futoin_json['env']['externalSetup'], {
                installTools => false,
            })
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
}
