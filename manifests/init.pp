
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
}
