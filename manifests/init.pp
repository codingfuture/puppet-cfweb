
class cfweb (
    $cluster,
    $is_secondary = false,
    $standalone = [],
    $backends = [],
    $frontends = [],
    $web_service = 'cfnginx',
) inherits cfweb::global {
    cfsystem_info { 'cfweb':
        ensure => present,
        info => {
            cluster      => $cluster,
            is_secondary => $is_secondary,
            web_service  => $web_service,
        }
    }
    
    # Standalone - public facing
    # NOTE: they still can work in HA cluster
    #---
    $standalone.each |$site_name| {
        create_resources(
                'cfweb::site',
                {
                    $site_name => {
                        is_backend => false,
                    }
                },
                $cfweb::global::sites[$site_name]
        )
    }

    
    # Backends - sites which expect proxy_protocol
    # NOTE: must face only load balancer
    #---
    $backends.each |$site_name| {
        create_resources(
                'cfweb::site',
                {
                    $site_name => {
                        is_backend => false,
                    }
                },
                $cfweb::global::sites[$site_name]
        )
    }
    
    
    # Frontends - load balancing with proxy_protocol
    #---
    $frontends.each |$site_name| {
        fail('TODO: frontends are not supported yet')
    }
}
