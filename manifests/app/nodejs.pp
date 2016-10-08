
define cfweb::app::nodejs (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,
    String[1] $template_global = 'cfweb/upstream_nodejs',
    String[1] $template = 'cfweb/app_nodejs',
    
    String[1] $version = 'lts/*',
    Optional[Integer[1]] $count = undef,
    Array[String[1]] $locations = [],
    
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,
    
    String[1] $entry_point = 'app.js',
    Struct[{
        mem_per_conn => Optional[Integer[1]],
        rlimit_files => Optional[Integer[1]],
        new_mem_ratio => Optional[Float[0.0, 1.0]],
    }] $tune = {},
) {
    require cfweb::appcommon::nvm
    ensure_resource('cfweb::appcommon::nodejs', $version, {})
    
    $service_name = "app-${site}-nodejs"
    
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
    $node_sock = "/run/${service_name}/node.sock"
    $upstream = "nodejs_${site}"
    
    file { "${conf_prefix}.global.nodejs":
        mode    => '0640',
        content => epp($template_global, {
            upstream   => $upstream,
            node_sock  => $node_sock,
            sock_count => $count_act,
        }),
    }
    file { "${conf_prefix}.server.nodejs":
        mode    => '0640',
        content => epp($template, {
            site      => $site,
            upstream  => $upstream,
            locations => $locations,
        }),
    }

    cfweb_app { $service_name:
        ensure        => present,
        type          => $type,
        site          => $site,
        user          => $user,
        service_name  => $service_name,
        site_dir      => $site_dir,
        
        cpu_weight    => $cpu_weight,
        io_weight     => $io_weight,
        
        misc          => {
            nvm_dir     => $cfweb::appcommon::nvm::dir,
            version     => $version,
            instances   => $count_act,
            entry_point => $entry_point,
            sock_base   => $node_sock,
            tune        => $tune,
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
        target => "${cfweb::nginx::generic_control}"
    }    
}
