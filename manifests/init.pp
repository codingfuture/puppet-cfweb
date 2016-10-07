
class cfweb (
    String[1] $cluster,
    Boolean $is_secondary = false,
    Array[String] $standalone = [],
    Array[String] $backends = [],
    Array[String] $frontends = [],
    String[1] $web_service = 'cfnginx',
    String[1] $internal_face = 'main',
) inherits cfweb::global {
    include cfnetwork
    
    validate_re($cluster, '^[a-z][a-z0-9_]*$')
    validate_re($web_service, '^[a-z][a-z0-9_]*$')
    
    $internal_addr = split(getparam(Cfnetwork::Iface[$internal_face], 'address'), '/')[0]
    
    if !$internal_addr {
        fail('$cfweb::internal_face must be set to interface with valid address')
    }
    
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
        $site = $cfweb::global::sites[$site_name]
        
        if !($site =~ Hash) {
            fail("Site '${site_name}' is missing from cfweb::global::sites: ${site}")
        }

        create_resources(
                'cfweb::site',
                {
                    $site_name => {
                        is_backend => false,
                    }
                },
                $site
        )
    }

    
    # Backends - sites which expect proxy_protocol
    # NOTE: must face only load balancer
    #---
    $backends.each |$site_name| {
        $site = $cfweb::global::sites[$site_name]
        
        if !($site =~ Hash) {
            fail("Site '${site_name}' is missing from cfweb::global::sites: ${site}")
        }
        
        create_resources(
                'cfweb::site',
                {
                    $site_name => {
                        is_backend => false,
                    }
                },
                $site
        )
    }
    
    
    # Frontends - load balancing with proxy_protocol
    #---
    $frontends.each |$site_name| {
        fail('TODO: frontends are not supported yet')
    }
}
