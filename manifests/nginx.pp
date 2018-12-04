#
# Copyright 2016-2018 (c) Andrey Galkin
#


class cfweb::nginx (
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = 256,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,
    Hash $settings_tune = {},
    Array[String] $trusted_proxy = [],
    Hash $default_certs = {},
    Integer[1] $backlog = 4096,
    Hash[String, Struct[{
        type       => Enum['conn', 'req'],
        var        => String[1],
        count      => Optional[Integer[1]],
        entry_size => Optional[Integer[1]],
        rate       => Optional[String],
        burst      => Optional[Integer[0]],
        nodelay    => Optional[Boolean],
    }]] $limits = {},
    Optional[Array[String[1]]] $stress_hosts = undef,
    Boolean $bleeding_edge_security = false,

    String $repo = 'http://nginx.org/packages/',
    Boolean $mainline = false,
) {
    include stdlib
    include cfnetwork
    include cfweb
    include cfweb::pki

    $nginx_repo = $mainline ? {
        true => "${repo}mainline/",
        default => $repo,
    }

    case $::operatingsystem {
        'Debian', 'Ubuntu': {
            class { 'cfweb::nginx::aptrepo': stage => 'cf-apt-setup' }
            $package = 'nginx'
        }
        default: { fail("Not supported OS ${::operatingsystem}") }
    }

    $service_name = $cfweb::web_service
    $user = $service_name
    $group = $user

    $conf_dir = '/etc/nginx'
    $sites_dir = "${conf_dir}/sites"
    $clientpki_dir = "${conf_dir}/clientpki"

    $web_dir = $cfweb::web_dir
    $persistent_dir = "${web_dir}/persistent"
    $bin_dir = "${web_dir}/bin"
    $generic_control = "${bin_dir}/generic_control.sh"
    $empty_root = "${web_dir}/empty"
    $errors_root = "${web_dir}/error"
    $acme_challenge_group = $cfweb::acme_challenge_group
    $acme_challenge_root = $cfweb::acme_challenge_root

    #---
    $act_settings_tune = merge(
        {
            cfweb => merge(
                {
                    use_syslog => $cflogsink::centralized,
                },
                pick($settings_tune['cfweb'], {})
            )
        },
        $settings_tune
    )

    if $act_settings_tune['cfweb']['use_syslog'] {
        include cflogsink::hdsyslog
    }
    #---


    group { $group:
        ensure => present,
    }
    -> user { $user:
        ensure => present,
        gid    => $group,
        home   => $conf_dir,
        system => true,
    }
    -> package { $package: }
    -> cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 32,
        max_mb => $memory_max,
    }
    -> file { $conf_dir:
        ensure  => directory,
        group   => $group,
        mode    => '0750',
        purge   => true,
        recurse => true,
        force   => true,
    }
    -> file { [ "${conf_dir}/nginx.conf", "${conf_dir}/log.conf" ]:
        group   => $group,
        mode    => '0640',
        replace => false,
        content => '',
    }
    -> file { "${conf_dir}/cf_tls.conf":
        group   => $group,
        mode    => '0640',
        content => epp('cfweb/cf_tls.conf.epp', {
            dhparam       => $cfweb::pki::dhparam,
            ticket_count  => $cfweb::pki::tls_ticket_key_count,
            ticket_dir    => $cfweb::pki::ticket_dir,
            dns_servers   => join(any2array($cfnetwork::dns_servers), ' '),
            bleeding_edge => $bleeding_edge_security,
        })
    }
    -> file { [$sites_dir, $clientpki_dir]:
        ensure  => directory,
        group   => $group,
        mode    => '0750',
        purge   => true,
        recurse => true,
        force   => true,
    }
    -> file { [$web_dir, $errors_root, $persistent_dir]:
        ensure => directory,
        owner  => root,
        group  => $group,
        mode   => '0751',
    }
    -> file { [$empty_root, $bin_dir]:
        ensure  => directory,
        mode    => '0751',
        owner   => root,
        group   => $group,
        purge   => true,
        recurse => true,
        force   => true,
    }
    -> file { $generic_control:
        content => file('cfweb/generic_control.sh'),
        mode    => '0750',
        owner   => root,
        group   => $group,
    }
    -> file { [
            "${bin_dir}/start",
            "${bin_dir}/stop",
            "${bin_dir}/restart",
            "${bin_dir}/reload",
            "${bin_dir}/deploy",
        ]:
        ensure => link,
        target => $generic_control,
    }
    -> group { $acme_challenge_group:
        ensure => present
    }
    -> cfweb::nginx::group { $acme_challenge_group: }
    -> file { [
            $acme_challenge_root,
            "${acme_challenge_root}/.well-known",
            "${acme_challenge_root}/.well-known/acme-challenge",
        ]:
        ensure => directory,
        group  => $acme_challenge_group,
        mode   => '2770',
    }
    -> cfweb_nginx { $service_name:
        ensure        => present,
        memory_weight => $memory_weight,
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,
        settings_tune => $act_settings_tune,
        service_name  => $service_name,
        limits        => $limits,
        stress_hosts  => $stress_hosts,
    }
    -> anchor { 'cfnginx-ready': }
    -> exec { 'cfweb_reload':
        command     => '/bin/systemctl reload-or-restart cfnginx.service',
        onlyif      => '/usr/bin/test -f /etc/systemd/system/cfnginx.service',
        refreshonly => true,
    }

    [
        'cf_mime.types',
        'cf_http_params',
        'cf_fastcgi_params',
        'cf_scgi_params',
        'cf_uwsgi_params'
    ].each |$v| {
        file { "${conf_dir}/${v}":
            group   => $group,
            mode    => '0640',
            content => file("cfweb/${v}"),
            notify  => Cfweb_nginx[$service_name]
        }
    }


    ['forbidden', 'notfound', 'oops'].each |$v| {
        file { "${errors_root}/${v}.html":
            owner   => $user,
            group   => $group,
            mode    => '0640',
            content => file("cfweb/${v}.html"),
        }
    }

    # OCSP
    #---
    cfnetwork::client_port { 'any:cfhttp:nginx':
        user => $user
    }

    # Stats
    #---
    cfsystem::metric { 'nginx': }
}
