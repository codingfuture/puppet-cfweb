
class cfweb::nginx (
    $memory_weight = 100,
    $memory_max = undef,
    $cpu_weight = 100,
    $io_weight = 100,
    $settings_tune = {},
) {
    include stdlib
    include cfweb
    
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
    } ->
    file { $sites_dir:
        ensure  => directory,
        mode    => '0750',
        purge   => true,
        recurse => true,
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
    } ->
    service { $service_name: }
    
    
    ['forbidden', 'notfound', 'oops'].each |$v| {
        file { "${errors_root}/${v}.html":
            owner   => $user,
            group   => $user,
            mode    => '0640',
            content => file("cfweb/${v}.html"),
        }
    }
}