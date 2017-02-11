#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::app::nodejs (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,
    String[1] $template_global = 'cfweb/upstream_nodejs',
    String[1] $template = 'cfweb/app_nodejs',

    String[1] $version = 'lts/*',
    Optional[Integer[1]] $count = undef,
    Array[String[1]] $locations = [],

    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,

    String[1] $entry_point = 'app.js',
    Struct[{
        mem_per_conn_kb => Optional[Integer[1]],
        new_mem_ratio => Optional[Float[0.0, 1.0]],
        node_env => Optional[String[1]],
    }] $tune = {},
    Boolean $build_support = false,
) {
    require cfweb::appcommon::nvm
    ensure_resource('cfweb::appcommon::nodejs', $version,
                    { build_support => $build_support })

    $service_name = "app-${site}-${type}"

    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 32,
        max_mb => $memory_max,
    }

    $count_act = $count ? {
        undef   => $::facts['processorcount'],
        default => $count,
    }

    #---
    $node_sock = "/run/${service_name}/node.sock"
    $upstream = "${type}_${site}"

    file { "${conf_prefix}.global.${type}":
        mode    => '0640',
        content => epp($template_global, {
            upstream   => $upstream,
            node_sock  => $node_sock,
            sock_count => $count_act,
        }),
    }
    file { "${conf_prefix}.server.${type}":
        mode    => '0640',
        content => epp($template, {
            site      => $site,
            upstream  => $upstream,
            locations => $locations,
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

        misc         => {
            nvm_dir     => $cfweb::appcommon::nvm::dir,
            version     => $version,
            instances   => $count_act,
            entry_point => $entry_point,
            sock_base   => $node_sock,
            tune        => $tune,
        },
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
