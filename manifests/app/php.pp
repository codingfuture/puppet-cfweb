
define cfweb::app::php (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,
    String[1] $template_global = 'cfweb/upstream_php',
    String[1] $template = 'cfweb/app_php',

    Hash[String[1],Hash] $dbaccess = {},

    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,

    Hash[String[1], Any] $php_ini = {},
    Hash[
        Enum['global', 'pool'],
        Hash[String[1], Any]
    ] $fpm_tune = {},

    Boolean $is_debug = false,
    Array[String] $extension = [],
    Array[String] $default_extension = [
        'apcu',
        'curl',
        'json',
        'opcache',
        'pdo',
        'xmlrpc',
    ],

    Variant[Boolean, Integer] $memcache_sessions = true,
) {
    require cfweb::appcommon::php

    $service_name = "app-${site}-${type}"

    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 32,
        max_mb => $memory_max,
    }

    $web_root = getparam(Cfweb::Site[$site], 'web_root')
    $fpm_sock = "/run/${service_name}/php-fpm.sock"
    $upstream = "${type}_${site}"

    file { "${conf_prefix}.global.${type}":
        mode    => '0640',
        content => epp($template_global, {
            upstream => $upstream,
            fpm_sock => $fpm_sock,
            max_conn => try_get_value(
                $::facts,
                "cfweb/sites/${site}/apps/${type}/maxconn",
                1
            ),
        }),
    }
    file { "${conf_prefix}.server.${type}":
        mode    => '0640',
        content => epp($template, {
            site          => $site,
            upstream      => $upstream,
            document_root => "${site_dir}/current${web_root}",
        }),
    }

    #---
    $db_extension = unique($dbaccess_names.map |$name| {
        $config_vars = getparam(Cfweb::Appcommon::Dbaccess[$name], 'config_vars')

        if !($config_vars =~ Hash[String[1], Any]) {
            fail("By some reason Cfweb::Appcommon::Dbaccess[${name}] is not defined prior")
        }

        case $config_vars['type'] {
            'mysql': {
                if $cfweb::appcommon::php::is_v7 {
                    $pkg = 'mysql'
                } else {
                    $pkg = 'mysqlnd'
                }

                ensure_packages(["${cfweb::appcommon::php::pkgprefix}-${pkg}"])
                $ext = 'mysql'
            }
            'postgresql': {
                ensure_packages(["${cfweb::appcommon::php::pkgprefix}-pgsql"])
                $ext = 'pgsql'
            }
            'redis': {
                ensure_packages(["${cfweb::appcommon::php::pkgprefix}-redis"])
                $ext = 'redis'
            }
            default: {
                $ext = undef
            }
        }
        $ext
    })

    #---
    if $is_debug {
        ensure_packages(["${cfweb::appcommon::php::pkgprefix}-xdebug"])
    }

    if $memcache_sessions {
        require cfweb::appcommon::memcached
        ensure_packages(["${cfweb::appcommon::php::pkgprefix}-memcache"])

        $memcache_servers = cf_query_resources(
            "Class['cfweb']{ cluster = '${cfweb::cluster}'} and Cfweb_app['${service_name}']",
            "Cfweb_app['${service_name}']",
            false
        ).reduce([]) |$memo, $v| {
            $params = $v['parameters']
            $memc = $params['misc']['memcache']
            $certname = $v['certname']

            if $memc and $certname != $::trusted['certname'] {
                $memo + [{
                    host => $memc['host'],
                    port => $memc['port'],
                }]
            } else {
                $memo
            }
        }

        $memcache_port = cf_genport("cfweb/${site}-phpsess")
        $memcache = {
            sessions => $memcache_sessions,
            servers  => cf_stable_sort($memcache_servers),
            host     => $cfweb::internal_addr,
            port     => $memcache_port,
        }

        $memcache_servers.each |$v| {
            $host = $v['host']
            $port = $v['port']
            $fwservice = "cfweb_memcache_${port}"
            ensure_resource(
                'cfnetwork::describe_service',
                $fwservice,
                {
                    server => "tcp/${port}"
                }
            )
            cfnetwork::client_port { "${cfweb::internal_face}:${fwservice}:${host}":
                dst  => $host,
                user => $user,
            }
        }

        with($memcache) |$v| {
            $host = $v['host']
            $port = $v['port']
            $fwservice = "cfweb_memcache_${port}"
            ensure_resource(
                'cfnetwork::describe_service',
                $fwservice,
                {
                    server => "tcp/${port}"
                }
            )
            cfnetwork::client_port { "local:${fwservice}":
                dst  => $host,
                user => $user,
            }

            cfnetwork::service_port { "local:${fwservice}": }

            if size($memcache_servers) {
                cfnetwork::service_port { "${cfweb::internal_face}:${fwservice}":
                    src  => $memcache_servers.map |$v| { $v['host'] },
                }
            }
        }
    } else {
        $memcache = undef
    }

    #---
    $conf_dir = "${site_dir}/.php"

    file { $conf_dir:
        ensure => directory,
        owner  => $user,
        group  => $user,
        mode   => '0500',
    } ->
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
            php_ini   => $php_ini,
            fpm_tune  => $fpm_tune,
            is_debug  => $is_debug,
            fpm_bin   => $cfweb::appcommon::php::fpm_service,
            memcache  => $memcache,
            extension => unique(
                $extension +
                $default_extension +
                $db_extension +
                ($is_debug ? {
                    true    => ['xdebug'],
                    default => [],
                }) +
                ($memcache_sessions ? {
                    true    => ['memcache'],
                    default => [],
                })
            ),
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
