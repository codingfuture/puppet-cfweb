
class cfweb::nginx (
    Integer $memory_weight = 100,
    Optional[Integer] $memory_max = undef,
    Integer $cpu_weight = 100,
    Integer $io_weight = 100,
    Hash $settings_tune = {},
    Array[String] $trusted_proxy = [],
    Hash $default_certs = {},
    Integer $backlog = 4096,
    Hash $limits,
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
    $persistent_dir = '/www/persistent'
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
    file { "${conf_dir}/nginx.conf":
        mode    => '0640',
        replace => false,
        content => '',
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
    } ->
    file { $sites_dir:
        ensure  => directory,
        mode    => '0750',
    } ->
    file { [$web_dir, $errors_root, $persistent_dir]:
        ensure => directory,
        owner => root,
        group => $user,
        mode  => '0751',
    } ->
    file { $empty_root:
        ensure => directory,
        mode  => '0751',
        owner => root,
        group => $user,
        purge => true,
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