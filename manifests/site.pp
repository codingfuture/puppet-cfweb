#
# Copyright 2016-2019 (c) Andrey Galkin
#


define cfweb::site (
    String[1] $server_name = $title,
    Array[String[1]] $alt_names = [],
    Boolean $redirect_alt_names = true,

    Array[String[1]] $ifaces = ['main'],
    Array[Cfnetwork::Port] $plain_ports = [80],
    Array[Cfnetwork::Port] $tls_ports = [443],
    Boolean $redirect_plain = true,

    Boolean $is_backend = false,
    Boolean $proxy_protocol = true,

    Hash[String[1], Any] $auto_cert = {},
    CfWeb::SharedCert $shared_cert = [],
    Hash[String[1], CfWeb::DBAccess] $dbaccess = {},
    Hash[String[1],Hash,1] $apps = { 'static' => {} },
    Optional[String[1]] $custom_conf = undef,

    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,

    CfWeb::Limits $limits = {},
    CfWeb::DotEnv $dotenv = {},

    Optional[Hash[String[1], Any]] $deploy = undef,
    Optional[String[1]] $force_user = undef,

    Boolean $robots_noindex = false,
    Optional[String[1]] $require_realm = undef,
    Optional[String[1]] $require_hosts = undef,
    Optional[CfWeb::ClientX509] $require_x509 = undef,
    Optional[String[1]] $hsts = 'max-age=15768000; includeSubDomains; preload',

    Boolean $backup_persistent = false,
) {
    include cfdb
    include cfweb::nginx
    include cfweb::global

    validate_re($title, '^[a-z][a-z0-9_]*$')

    #---
    if 'docker' in $apps {
        # Ensure cfnetwork resource
        include cfweb::appcommon::docker
    }

    #---
    $shared_certs = any2array($shared_cert)

    if size($shared_certs) > 0 {
        $shared_certs.each |$cert_name| {
            $cert_params = $cfweb::global::certs[$cert_name]

            ensure_resource(
                'cfweb::pki::cert',
                $cert_name,
                $cert_params
            )
        }
        $dep_certs = $shared_certs
    } elsif size($tls_ports) > 0 {
        $auto_cert_name = "auto#${server_name}"
        ensure_resource(
            'cfweb::pki::cert',
            $auto_cert_name,
            merge(
                $auto_cert,
                {
                    cert_name => $server_name,
                    alt_names => $alt_names,
                }
            )
        )

        $dep_certs = [$auto_cert_name]
    } else {
        $dep_certs = []
    }

    if size($dep_certs) {
        $dep_certs_resources = Cfweb::Pki::Cert[$dep_certs]
    } else {
        $dep_certs_resources = undef
    }

    # Default hosts configure listen socket
    #---
    $iface = undef # make buggy puppet-lint happy
    $ifaces.each |$iface| {
        $plain = $plain_ports.each |$port| {
            ensure_resource('cfweb::nginx::defaulthost', "${iface}:${port}", {
                iface      => $iface,
                port       => $port,
                tls        => false,
                is_backend => $is_backend,
                proxy_protocol => $proxy_protocol,
            })
        }
        $tls = $tls_ports.each |$port| {
            ensure_resource('cfweb::nginx::defaulthost', "${iface}:${port}", {
                iface      => $iface,
                port       => $port,
                tls        => true,
                is_backend => $is_backend,
                proxy_protocol => $proxy_protocol,
            })
        }
    }

    # Basic file structure
    #---
    $site = "app_${title}"

    $is_dynamic = $apps.reduce(false) |$m, $v| {
        $t = pick($v[1]['type'], $v[0])
        $r = $t in ['static', 'proxy', 'backend']
        $m or !$r
    }

    $user = $force_user ? {
        undef => $is_dynamic ? {
            true => $site,
            default => $cfweb::nginx::user
        },
        default => $force_user,
    }

    $group = $user

    $site_dir = "${cfweb::nginx::web_dir}/${site}"
    $deployer_home = $site_dir
    $home_dir = $site_dir
    $tmp_dir = "${site_dir}/.tmp"
    $persistent_dir = "${cfweb::nginx::persistent_dir}/${site}"
    $conf_prefix = "${cfweb::nginx::sites_dir}/${site}"
    # This must be created by deploy script
    $document_root = "${site_dir}/current"
    $env_file = "${site_dir}/.env"

    if $is_dynamic or $deploy {
        ensure_resource('cfweb::nginx::group', $group)
    }

    if $is_dynamic {
        include cfweb::appcommon::cid
        $cid_group = $cfweb::appcommon::cid::group

        ensure_resource('group', $group, { ensure => present })
        ensure_resource( 'user', $user, {
            ensure         => present,
            gid            => $group,
            groups         => [$cid_group],
            home           => $home_dir,
            purge_ssh_keys => true,
            system         => true,
            require        => Group[$group],
        })

        file { [
                "${cfweb::nginx::bin_dir}/start-${title}",
                "${cfweb::nginx::bin_dir}/stop-${title}",
                "${cfweb::nginx::bin_dir}/restart-${title}",
                "${cfweb::nginx::bin_dir}/reload-${title}",
            ]:
            ensure => link,
            target => $cfweb::nginx::generic_control
        }

        $dotenv.each |$k, $v| {
            cfsystem::dotenv { "${env_file}:${k}":
                user     => $user,
                variable => $k,
                value    => $v,
                env_file => $env_file,
                notify   => Cfweb_App[$user],
            }
        }
    }

    file { $site_dir:
        ensure  => directory,
        mode    => '0770',
        owner   => $user,
        group   => $group,
        require => User[$user],
    }

    file { $document_root:
        ensure  => link,
        replace => false,
        target  => $cfweb::nginx::empty_root,
    }

    if $is_dynamic or $deploy {
        file { [$persistent_dir, $tmp_dir]:
            ensure  => directory,
            mode    => '1770',
            owner   => $user,
            group   => $group,
            require => User[$user],
        }

        if $backup_persistent {
            cfbackup::path { $persistent_dir:
                namespace => cfweb,
                id        => $site,
                type      => files,
                require   => FIle[$persistent_dir],
            }
        }
    }


    # DB access
    #---
    if $is_dynamic and $dbaccess {
        $dbaccess_deps = ($dbaccess.map |$k, $da| {
            $name = "${title}:${k}"
            create_resources(
                'cfdb::access',
                { $name => {
                    local_user    => $user,
                    custom_config => 'cfweb::appcommon::dbaccess',
                    env_file      => $env_file,
                } },
                merge({
                    # TODO: get rid of facts
                    max_connections => pick_default(
                        $::facts.dig('cfweb', 'sites', $title, $k),
                        $cfdb::max_connections_default
                    ),
                    config_prefix => "DB_${k.upcase()}_",
                }, $da)
            )
            $name
        })


        $dbaccess_app_deps = ($apps.reduce({}) |$memo, $v| {
            $app = $v[0]
            $app_info = $v[1]
            $app_type = split($app, ':')[-1]

            $names = pick($app_info['dbaccess'], {}).map |$k, $da| {
                    $name = "${title}-${app_type}:${k}"
                    create_resources(
                        'cfdb::access',
                        { $name => {
                            local_user    => $user,
                            custom_config => 'cfweb::appcommon::dbaccess',
                            env_file      => $env_file,
                            config_prefix => "DB_${app_type.upcase()}_",
                        } },
                        merge({
                            # TODO: get rid of facts
                            max_connections => pick_default(
                                $::facts.dig('cfweb', 'sites', $title, $app_type),
                                $cfdb::max_connections_default
                            ),
                        }, $da)
                    )
                    $name
                }

            merge($memo, { $app => $names })
        })
    } else {
        $dbaccess_deps = []
        $dbaccess_app_deps = {}
    }

    $all_db_names = (
        $dbaccess_deps +
        flatten($dbaccess_app_deps.values())
    )
    $all_db_deps = Cfweb::Appcommon::Dbaccess[$all_db_names]

    # Define apps
    #---
    $cfg_notify = [
        Exec['cfweb_reload'],
    ]

    if $is_dynamic {
        # Define global app slice
        cfweb_app { $user:
            ensure     => present,
            type       => 'global',
            site       => $title,
            user       => $user,
            site_dir   => $site_dir,

            cpu_weight => $cpu_weight,
            io_weight  => $io_weight,

            misc       => {},
        }
    }

    $common_params = {
        site           => $title,
        user           => $user,
        site_dir       => $site_dir,
        conf_prefix    => $conf_prefix,
        dbaccess_names => $all_db_names,
        persistent_dir => $persistent_dir,
        apps           => keys($apps),
    }

    $apps.each |$app, $app_info| {
        $app_type = pick($app_info['type'], $app)
        $puppet_type = size(split($app_type, ':')) ? {
            1       => "cfweb::app::${app_type}",
            default => $app_type,
        }

        $app_dbaccess_deps = $dbaccess_deps +
                pick($dbaccess_app_deps[$app], [])

        create_resources(
            $puppet_type,
            {
                "${title}:${app}" => {
                    common => $common_params + {
                        app_name       => $app,
                        type           => split($app, ':')[-1],
                        dbaccess_names => $app_dbaccess_deps,
                    },
                    require =>
                        Cfweb::Appcommon::Dbaccess[$app_dbaccess_deps],
                    notify  => $cfg_notify,
                    before  => Anchor['cfnginx-ready'],
                },
            },
            $app_info - 'type'
        )
    }

    # Create vhost file
    #---
    if size($dep_certs) {
        include cfweb::pki

        $certs = $dep_certs.map |$cert_name| {
            cfweb::certinfo($cert_name)
        }
    } else {
        $certs = []
    }

    $bind = $ifaces.map |$iface| {
        $iface ? {
            'any' => '*',
            default => cfnetwork::bind_address($iface),
        }
    }

    $trusted_proxy = $is_backend ? {
        true => any2array($cfweb::nginx::trusted_proxy),
        default => undef
    }

    if $require_hosts {
        $require_host_list = $cfweb::global::hosts[$require_hosts]

        if !$require_host_list {
            fail("Missing \$cfweb::global::hosts[${require_hosts}]")
        }
    } else {
        $require_host_list = undef
    }

    if $require_x509 {
        if $require_x509 =~ String {
            $clientpki = $require_x509
        } else {
            $clientpki = $require_x509['clientpki']
        }
        ensure_resource('cfweb::internal::clientpki', $clientpki)
    }

    file { "${conf_prefix}.conf":
        mode    => '0640',
        content => epp('cfweb/app_vhost.epp', {
            site               => $title,
            conf_prefix        => $conf_prefix,

            server_name        => $server_name,
            alt_names          => $alt_names,
            redirect_alt_names => $redirect_alt_names,
            bind               => $bind,
            plain_ports        => $plain_ports,
            tls_ports          => $tls_ports,
            redirect_plain     => $redirect_plain,
            proxy_protocol     => $is_backend and $proxy_protocol,
            is_backend         => $is_backend,
            trusted_proxy      => $trusted_proxy,

            certs              => $certs,
            apps               => keys($apps),

            custom_conf        => pick_default($custom_conf, ''),
            robots_noindex     => $robots_noindex,
            require_realm      => $require_realm,
            require_host_list  => $require_host_list,
            require_x509       => $require_x509,
            hsts               => $hsts,
        }),
        notify  => $cfg_notify,
        before  => Anchor['cfnginx-ready'],
    }

    # Password database
    #---
    if $require_realm {
        file { "${conf_prefix}.passwd":
            group   => $cfweb::nginx::group,
            mode    => '0640',
            content => cfweb::passwd_db($require_realm),
            notify  => $cfg_notify,
            before  => Anchor['cfnginx-ready'],
        }
    }

    # Deploy procedure
    #---
    if $deploy {
        if 'docker' in $apps {
            $def_deploy_strategy = 'docker'
        } else {
            $def_deploy_strategy = 'futoin'
        }

        $deploy_strategy = pick($deploy['strategy'], $def_deploy_strategy)

        cfweb::deploy { $title:
            strategy => $deploy_strategy,
            params   => $deploy - strategy,
            common   => $common_params + {
                type     => $deploy_strategy,
                app_name => 'deploy',
                apps     => keys($apps),
            },
            require  => $all_db_deps,
            before   => Anchor['cfnginx-ready'],
        }
    }

    # Auto discovery
    #---
    if $is_backend {
        $backend_host = $ifaces[0] ? {
            'any' => cfnetwork::bind_address('main'),
            default => cfnetwork::bind_address($ifaces[0]),
        }
        cfweb::internal::backend { $title:
            host     => $backend_host,
            port     => $plain_ports[0],
            location => $cfsystem::hierapool::location,
            pool     => $cfsystem::hierapool::pool,
        }
    }
}
