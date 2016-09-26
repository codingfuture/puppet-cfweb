
class cfweb::nginx (
    $memory_weight = 100,
    $memory_max = undef,
    $cpu_weight = 100,
    $io_weight = 100,
    $settings_tune = {},
    $trusted_proxy = [],
    $default_certs = {},
    $backlog = 4096,
    $limits,
    $bleeding_edge_security = false,
    
    $repo = 'http://nginx.org/packages/',
    $mainline = false,
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
        'Debian': {
            class { 'cfweb::nginx::debian': stage => 'setup' }
            $package = 'nginx'
        }
        'Ubuntu': {
            class { 'cfweb::nginx::ubuntu': stage => 'setup' }
            $package = 'nginx'
        }
        default: { fail("Not supported OS ${::operatingsystem}") }
    }
    
    $service_name = $cfweb::web_service
    $user = $service_name
    
    $conf_dir = '/etc/nginx'
    $sites_dir = "${conf_dir}/sites"
    
    $web_dir = '/www'
    $empty_root = "${web_dir}/empty"
    $errors_root = "${web_dir}/error"
    
    group { $user:
        ensure => present,
    } ->
    user { $user:
        ensure => present,
        gid => $user,
        home => $conf_dir,
        require => Group[$user],
    } ->
    package { $package: } ->
    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 32,
        max_mb => $memory_max,
    } ->
    file { $conf_dir:
        ensure => directory,
        mode => '0750',
        purge   => true,
        recurse => true,
        force   => true,
    } ->
    file { "${conf_dir}/cf_tls.conf":
        mode => '0640',
        content => epp('cfweb/cf_tls.conf.epp', {
            dhparam       => $cfweb::pki::dhparam,
            ticket_count  => $cfweb::pki::tls_ticket_key_count,
            ticket_dir    => $cfweb::pki::ticket_dir,
            dns_servers   => join(any2array($cfnetwork::dns_servers), ' '),
            bleeding_edge => $bleeding_edge_security,
        })
    }
    file { $sites_dir:
        ensure  => directory,
        mode    => '0750',
    } ->
    file { [$web_dir, $empty_root, $errors_root]:
        ensure => directory,
        owner => root,
        group => $user,
        mode  => '0751',
    } ->
    cfweb_nginx { $service_name:
        ensure => present,
        memory_weight => $memory_weight,
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,
        settings_tune => $settings_tune,
        service_name  => $service_name,
        limits        => $limits,
    } ->
    service { $service_name: }
    
    [
        'cf_mime.types',
        'cf_fastcgi_params',
        'cf_scgi_params',
        'cf_uwsgi_params'
    ].each |$v| {
        file { "${conf_dir}/${v}":
            mode    => '0640',
            content => file("cfweb/${v}"),
            notify  => Cfweb_nginx[$service_name]
        }
    }
    
    
    ['forbidden', 'notfound', 'oops'].each |$v| {
        file { "${errors_root}/${v}.html":
            owner   => $user,
            group   => $user,
            mode    => '0640',
            content => file("cfweb/${v}.html"),
        }
    }
}