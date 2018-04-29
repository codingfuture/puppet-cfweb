#
# Copyright 2016-2018 (c) Andrey Galkin
#


define cfweb::app::futoin (
    CfWeb::AppCommonParams $common,

    Integer[1] $memory_weight = 100,
    Variant[Integer[0,0],Integer[64]] $memory_min = 64,
    Optional[Variant[Integer[0,0],Integer[64]]] $memory_max = undef,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,

    Hash $tune = {},
    Hash[String[1], Hash] $fw_ports = {},
    Optional[Hash[String[1], Any]] $deploy = undef,
) {
    #---
    $site = $common['site']
    $app_name = $common['app_name']
    $conf_prefix = $common['conf_prefix']
    $site_dir = $common['site_dir']
    $user = $common['user']
    $persist_dir = $common['persistent_dir']

    $service_name = "app-${site}-${app_name}"

    if size($common['apps']) != 1 {
        $deploy_dir = "${site_dir}/${app_name}"
        $app_persist_dir = "${persist_dir}/${app_name}"

        file { $deploy_dir:
            ensure => directory,
            owner  => $user,
            group  => $user,
            mode   => '0750',
        }
        file { $app_persist_dir:
            ensure => directory,
            owner  => $user,
            group  => $user,
            mode   => '0750',
        }
        -> file { "${deploy_dir}/.env":
            ensure => link,
            target => '../.env',
            owner  => $user,
            group  => $user,
            mode   => '0640',
        }
    } else {
        $deploy_dir = $site_dir
        $app_persist_dir = $persist_dir
    }

    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => $memory_min,
        max_mb => $memory_max,
    }

    #---
    cfweb::internal::appfw { "futoin-${title}":
        fw_ports => $fw_ports,
    }

    #---

    # prevent global failures on deploy issue
    file { [
            "${conf_prefix}.global.${app_name}",
            "${conf_prefix}.server.${app_name}",
        ]:
        ensure  => present,
        replace => no,
        content => '',
    }

    Class['cfweb::appcommon::cid']
    -> cfweb_app { $service_name:
        ensure       => present,
        type         => 'futoin',
        site         => $site,
        user         => $user,
        app_name     => $app_name,
        service_name => $service_name,
        site_dir     => $common['site_dir'],

        cpu_weight   => $cpu_weight,
        io_weight    => $io_weight,

        misc         => {
            conf_prefix => $conf_prefix,
            limits      => cfweb::limits_merge($site),
            deploy      => pick_default($deploy, getparam(Cfweb::Site[$site], 'deploy')),
            tune        => $tune,
            persist_dir => $app_persist_dir,
            deploy_dir  => $deploy_dir,
        },
        require      => [
            Anchor['cfnetwork:firewall'],
            Cfweb::Internal::Appfw["futoin-${title}"],
        ],
    }
    -> File["${conf_prefix}.conf"]

    #---
    file { [
            "${cfweb::nginx::bin_dir}/start-${site}-${app_name}",
            "${cfweb::nginx::bin_dir}/stop-${site}-${app_name}",
            "${cfweb::nginx::bin_dir}/restart-${site}-${app_name}",
            "${cfweb::nginx::bin_dir}/reload-${site}-${app_name}",
        ]:
        ensure => link,
        target => $cfweb::nginx::generic_control
    }

    #---
    if $deploy {
        cfweb::deploy { "${site}-${app_name}":
            strategy => futoin,
            params   => $deploy,
            common   => $common,
            require  => Cfweb::Appcommon::Dbaccess[$common['dbaccess_names']],
            before   => Anchor['cfnginx-ready'],
        }
    }
}
