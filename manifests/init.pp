
class cfweb (
    $cluster,
    $is_secondary = false,
    $standalone = [],
    $backends = [],
    $frontends = [],
) inherits cfweb::global {
    
    cfsystem_info { 'cfweb':
        ensure => present,
        info => {
            cluster      => $cluster,
            is_secondary => $is_secondary,
        }
    }
    
    if size($backends) > 0 {
        fail('Cluster setup is not supported yet')
    }
    
    if size($frontends) > 0 {
        fail('Cluster setup is not supported yet')
    }
}
