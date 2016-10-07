
define cfweb::app::php (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    Array[String[1]] $dbaccess,
    String[1] $template_global = 'cfweb/upstream_php',
    String[1] $template = 'cfweb/app_php',

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
) {
    require cfweb::appcommon::php
    
    $service_name = "app-${site}-php"
    
    cfsystem_memory_weight { $service_name:
        ensure => present,
        weight => $memory_weight,
        min_mb => 32,
        max_mb => $memory_max,
    }    
    
    $web_root = getparam(Cfweb::Site[$site], 'web_root')
    $fpm_sock = "/run/${service_name}/php-fpm.sock"
    $upstream = "php_${site}"
    
    file { "${conf_prefix}.global.php":
        mode    => '0640',
        content => epp($template_global, {
            upstream => $upstream,
            fpm_sock => $fpm_sock,
        }),
    }
    file { "${conf_prefix}.server.php":
        mode    => '0640',
        content => epp($template, {
            site          => $site,
            upstream      => $upstream,
            document_root => "${site_dir}/current${web_root}",
        }),
    }
    
    #---
    $db_extension = $dbaccess.map |$name| {
        $cfg = getparam(Cfweb::Appcommon::Dbaccess[$name], 'cfg_all')
        case $cfg['type'] {
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
                $ext = ''
            }
        }
        $ext
    }
    
    #---
    if $is_debug {
        ensure_packages(["${cfweb::appcommon::php::pkgprefix}-xdebug"])
    }
    
    #---
    $conf_dir = "${site_dir}/.php"
    $bin_dir = "${site_dir}/bin"
    
    file { $conf_dir:
        ensure => directory,
        owner  => $user,
        group  => $user,
        mode   => '0500',
    } ->
    cfweb_app { $service_name:
        ensure        => present,
        type          => 'php',
        site          => $site,
        user          => $user,
        service_name  => $service_name,
        site_dir      => $site_dir,
        
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,
        
        misc          => {
            php_ini   => $php_ini,
            fpm_tune  => $fpm_tune,
            is_debug  => $is_debug,
            fpm_bin   => $cfweb::appcommon::php::fpm_service,
            extension => unique(
                $extension +
                $default_extension +
                $db_extension +
                ($is_debug ? {
                    true => ['xdebug'],
                    default => [],
                })
            ),
        },
    }
    
    #---
    file { [
            "${cfweb::nginx::bin_dir}/start-${site}-php",
            "${cfweb::nginx::bin_dir}/stop-${site}-php",
            "${cfweb::nginx::bin_dir}/restart-${site}-php",
            "${cfweb::nginx::bin_dir}/reload-${site}-php",
        ]:
        ensure => link,
        target => "${cfweb::nginx::generic_control}"
    }
    
}
