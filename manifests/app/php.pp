
define cfweb::app::php (
    String $site,
    String $user,
    String $site_dir,
    String $conf_prefix,
    String $template_global = 'cfweb/upstream_php',
    String $template = 'cfweb/app_php',

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
) {
    require cfweb::appcommon::php
    
    cfsystem_memory_weight { "${user}:php":
        ensure => present,
        weight => $memory_weight,
        min_mb => 32,
        max_mb => $memory_max,
    }    
    
    $web_root = getparam(Cfweb::Site[$site], 'web_root')
    $fpm_sock = "/run/${user}/fpm.sock"
    
    file { "${conf_prefix}.global.php":
        mode    => '0640',
        content => epp($template_global, {
            user     => $user,
            fpm_sock => $fpm_sock,
        }),
    }
    file { "${conf_prefix}.server.php":
        mode    => '0640',
        content => epp($template, {
            fpm_sock        => $fpm_sock,
            document_root   => "${site_dir}/${web_root}",
        }),
    }
    
    $conf_dir = "${site_dir}/.php"
    $bin_dir = "${site_dir}/bin"
    
    file { $conf_dir:
        ensure => directory,
        owner  => $user,
        group  => $user,
        mode   => '0500',
    } ->
    cfweb_app { "${user}:php":
        ensure        => present,
        type          => 'php',
        site          => $site,
        user          => $user,
        site_dir      => $site_dir,
        
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,
        
        misc           => {
            php_ini  => $php_ini,
            fpm_tune => $fpm_tune,
            is_debug => $is_debug,
        },
    }
    
}
