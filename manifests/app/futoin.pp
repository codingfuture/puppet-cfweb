#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::app::futoin (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,

    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,

    Hash $tune = {},
) {
    if size(getparam(Cfweb::Site[$site], 'apps')) != 1 {
        fail('"futoin" CID must be exlusive app per site')
    }

    #---
    $service_name = "app-${site}-${type}"

    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 64,
        max_mb => $memory_max,
    }

    #---

    # prevent global failures on deploy issue
    file { [
            "${conf_prefix}.global.futoin",
            "${conf_prefix}.server.futoin",
        ]:
        ensure  => present,
        replace => no,
        content => '',
    }

    cfweb_app { $service_name:
        ensure       => present,
        type         => $type,
        site         => $site,
        user         => $user,
        service_name => $service_name,
        site_dir     => $site_dir,

        cpu_weight   => $cpu_weight,
        io_weight    => $io_weight,

        misc         => {
            conf_prefix => $conf_prefix,
            limits      => cfweb::limits_merge($site),
            deploy      => getparam(Cfweb::Site[$site], 'deploy'),
            tune        => $tune,
        },
        require      => Anchor['cfnetwork:firewall'],
    }
    -> File["${conf_prefix}.conf"]

    #---
    file { [
            "${cfweb::nginx::bin_dir}/start-${site}-${type}",
            "${cfweb::nginx::bin_dir}/stop-${site}-${type}",
            "${cfweb::nginx::bin_dir}/restart-${site}-${type}",
            "${cfweb::nginx::bin_dir}/reload-${site}-${type}",
        ]:
        ensure => link,
        target => $cfweb::nginx::generic_control
    }
}
