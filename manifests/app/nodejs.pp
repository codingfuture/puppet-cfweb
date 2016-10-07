
define cfweb::app::nodejs (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    Array[String[1]] $dbaccess,
    String[1] $template_global = 'cfweb/upstream_nodejs',
    String[1] $template = 'cfweb/app_nodejs',
    
    String[1] $version = 'lts/*',
    Optional[Integer[1]] $count = undef,
    Array[String[1]] $locations = [],
    
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,
) {
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

}
