
define cfweb::app::ruby (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,
    String[1] $template_global = 'cfweb/upstream_ruby',
    String[1] $template = 'cfweb/app_ruby',
    
    String[1] $version = 'ruby-2.2',
    Optional[Integer[1]] $count = undef,
    Array[String[1]] $locations = [],
    
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,    
    Struct[{
    }] $tune = {},
    Boolean $build_support = false,
) {
    require cfweb::appcommon::rvm
    ensure_resource('cfweb::appcommon::ruby', $version,
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
    $sock = "/run/${service_name}/${type}"
    $upstream = "${type}_${site}"
    
    file { "${conf_prefix}.global.${type}":
        mode    => '0640',
        content => epp($template_global, {
            upstream   => $upstream,
            sock       => $sock,
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

    /*cfweb_app { $service_name:
        ensure        => present,
        type          => $type,
        site          => $site,
        user          => $user,
        service_name  => $service_name,
        site_dir      => $site_dir,
        
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,
        
        misc          => {
            rvm_dir     => $cfweb::appcommon::rvm::dir,
            version     => $version,
            instances   => $count_act,
            sock_base   => $sock,
            tune        => $tune,
        },
    }*/
    
    #---
    file { [
            "${cfweb::nginx::bin_dir}/start-${site}-${type}",
            "${cfweb::nginx::bin_dir}/stop-${site}-${type}",
            "${cfweb::nginx::bin_dir}/restart-${site}-${type}",
            "${cfweb::nginx::bin_dir}/reload-${site}-${type}",
        ]:
        ensure => link,
        target => "${cfweb::nginx::generic_control}"
    }
}
