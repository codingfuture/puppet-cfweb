#
# Copyright 2016-2019 (c) Andrey Galkin
#


define cfweb::app::docker (
    CfWeb::AppCommonParams $common,

    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_min = undef,
    Optional[Integer[1]] $memory_max = undef,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,

    Hash $tune = {},
    Hash[String[1], Hash] $fw_ports = {},
    Optional[Hash[String[1], Any]] $deploy = undef,

    String[1] $path = '/',
    Optional[String[0]] $uppath = undef,
    Optional[Integer[0]] $keepalive = undef,
    CfWeb::Upstream $upstream = {},
    Boolean $skip_nginx = false,
) {
    include cfweb::appcommon::docker

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
    $fw_ports.each |$svc, $def| {
        create_resources('cfnetwork::router_port', {
            "docker/any:${svc}:${user}" => merge($def),
        })
    }

    #---
    $upstream_port = cfsystem::gen_port($service_name, $upstream['port'])
    $act_upstream = $upstream + {
        host => '127.0.0.1',
        port => $upstream_port,

    }
    $upname = "app_${site}_${app_name}"

    file { "${conf_prefix}.global.${app_name}":
        mode    => '0640',
        content => epp('cfweb/upstream_proxy', {
            upname    => $upname,
            upstreams => [$act_upstream],
            keepalive => pick($keepalive, pick($act_upstream['max_conn'], 64)/8),
        }),
    }
    file { "${conf_prefix}.server.${app_name}":
        mode    => '0640',
        content => epp('cfweb/app_proxy', {
            upname => $upname,
            path   => $path,
            uppath => pick_default($uppath, ''),
        }),
    }

    $fw_service = "proxy_${upstream_port}"

    ensure_resource('cfnetwork::describe_service', $fw_service, {
        server => "tcp/${upstream_port}",
    })
    ensure_resource('cfnetwork::service_port', "local:${fw_service}")
    ensure_resource('cfnetwork::client_port', "local:${fw_service}:${user}", {
        user => $cfweb::nginx::user,
    })

    #---

    Class['cfweb::appcommon::docker']
    -> cfweb_app { $service_name:
        ensure       => present,
        type         => 'docker',
        site         => $site,
        user         => $user,
        app_name     => $app_name,
        service_name => $service_name,
        site_dir     => $common['site_dir'],

        cpu_weight   => $cpu_weight,
        io_weight    => $io_weight,

        misc         => {
            conf_prefix => $conf_prefix,
            deploy      => pick_default($deploy, getparam(Cfweb::Site[$site], 'deploy')),
            tune        => $tune,
            persist_dir => $app_persist_dir,
            deploy_dir  => $deploy_dir,
            bind_port   => $upstream_port,
        },
        require      => [
            Anchor['cfnetwork:firewall'],
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
            strategy => docker,
            params   => $deploy,
            common   => $common,
            require  => Cfweb::Appcommon::Dbaccess[$common['dbaccess_names']],
            before   => Anchor['cfnginx-ready'],
        }
    }
}
