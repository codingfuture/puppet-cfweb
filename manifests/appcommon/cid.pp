#
# Copyright 2017-2019 (c) Andrey Galkin
#



class cfweb::appcommon::cid (
    String[1] $version = 'latest',
    Integer[0] $reserve_ram = 256,
) {
    include cfsystem::pip
    include cfweb
    include cfweb::nginx

    cfsystem_memory_weight { 'cfweb:cid':
        ensure => present,
        weight => 1,
        min_mb => $reserve_ram,
    }

    $user = 'futoin'
    $group = 'futoin'
    $home = "/home/${user}"
    $tool_dir = "${cfweb::web_dir}/tools"
    $deploy_callback = "${cfweb::nginx::bin_dir}/cf_cid_callback"
    $sudoers_file = "/etc/sudoers.d/${user}"

    $global_futoin_json = {
        env => {
            startup => systemd,
            webServer => nginx,
            externalSetup => "/usr/bin/sudo -u ${user} -n -H ${deploy_callback}",
            externalServices => ['nginx'],
            gvmDir => "${tool_dir}/gvm",
            rvmDir => "${tool_dir}/rvm",
            nvmDir => "${tool_dir}/nvm",
            composerDir => "${tool_dir}/composer",
            flywayDir => "${tool_dir}/flyway",
            liquibaseDir => "${tool_dir}/liquibase",
            sdkmanDir => "${tool_dir}/sdkman",
            phpBinOnly => true,
            phpfpmErrorLog => syslog,
        }
    }

    $user_futoin_json = {
        env => {
            externalSetup => false
        }
    }

    group { $group:
        ensure => present,
    }
    -> user { $user:
        ensure         => present,
        home           => $home,
        gid            => $group,
        system         => true,
        shell          => '/bin/bash',
        purge_ssh_keys => true,
    }

    package { 'futoin-cid':
        ensure   => $version,
        provider => cfpip2,
        require  => Package['pip'],
    }
    # -> exec { '/usr/local/bin/pip install -e /external/cid-tool': }
    -> file { '/etc/futoin':
        ensure => directory,
        mode   => '0755',
    }
    -> file { '/etc/futoin/futoin.json':
        mode    => '0644',
        content => cfsystem::pretty_json($global_futoin_json),
    }
    -> file { $home:
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0755',
    }
    -> file { "${home}/.futoin.json":
        mode    => '0444',
        content => cfsystem::pretty_json($user_futoin_json),
    }
    -> file { $deploy_callback:
        mode    => '0755',
        content => file('cfweb/cf_cid_callback.sh'),
    }
    -> file { $tool_dir:
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0755',
    }
    -> cfauth::sudoentry { "grp_${group}":
        user     => "%${group}",
        command  => [ $deploy_callback ],
        env_keep => [
            'nodeVer',
            'rubyVer',
            'phpVer',
            'phpExtRequire',
            'phpExtTry',
            'pythonVer',
        ],
    }
    -> exec { $sudoers_file:
        creates => $sudoers_file,
        command => "/bin/sh -c '/usr/local/bin/cid sudoers ${user} > ${sudoers_file}'",
    }
    -> file { $sudoers_file:
        mode => '0640',
    }
    -> file { '/etc/cron.d/php':
        ensure => absent,
    }

    # Disable PHP-fpm regardless if installed
    ['', '5.6', '7.0', '7.1', '7.2', '7.3', '7.4'].each |$ver| {
        exec { "cfweb-mask-php-fpm-${ver}":
            command => [
                "/bin/systemctl stop php${ver}-fpm",
                "/bin/systemctl mask php${ver}-fpm",
            ].join(';'),
            creates => "/etc/systemd/system/php${ver}-fpm.service",
        }
    }

    # Allow package retrieval
    cfnetwork::client_port { "any:cfhttp:${user}":
        user => $user,
    }

    class { 'cfweb::internal::cidrepos': stage => 'setup' }
}
