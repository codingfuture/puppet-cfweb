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
    String[1] $template_global = 'cfweb/upstream_futoin',
    String[1] $template = 'cfweb/app_http',

    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,
) {
    $service_name = "app-${site}-${type}"

    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 64,
        max_mb => $memory_max,
    }

    #---
    $sock = "/run/${service_name}/futoin.sock"
    $upstream = "${type}_${site}"

    file { "${conf_prefix}.global.${type}":
        mode    => '0640',
        content => epp($template_global, {
            upstream    => $upstream,
            futoin_sock => $sock,
        }),
    }
    file { "${conf_prefix}.server.${type}":
        mode    => '0640',
        content => epp($template, {
            site      => $site,
            upstream  => $upstream,
            locations => ['/'],
        }),
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
    }

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
