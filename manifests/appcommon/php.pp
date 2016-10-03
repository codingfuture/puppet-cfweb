
class cfweb::appcommon::php(
    Boolean $popular_packages = true,
    Array[String] $extension = [],
) {
    if ($::facts['operatingsystem'] == 'Debian' and
        versioncmp($::facts['operatingsystemrelease'], '9') >= 0) or
       ($::facts['operatingsystem'] == 'Ubuntu' and
        versioncmp($::facts['operatingsystemrelease'], '16.04') >= 0)
    {
        $is_v7 = true
        $php_ver = '7.0' # TODO: fact
        $pkgprefix = "php${php_ver}"
        $php_etc_root = "/etc/php/${php_ver}"
        $fpm_service = "php${php_ver}-fpm"
        
        $extra_pkgs = [
            "${pkgprefix}-bcmath",        
            "${pkgprefix}-bz2",
            "${pkgprefix}-mbstring",
            "${pkgprefix}-opcache",
            "${pkgprefix}-soap",
            "${pkgprefix}-xml",
            "${pkgprefix}-zip",
        ]
    } else {
        $is_v7 = false
        $pkgprefix = 'php5'
        $php_etc_root = '/etc/php5'
        $fpm_service = "${pkgprefix}-fpm"
        $extra_pkgs = []
    }
    
    $fpm_package = "${pkgprefix}-fpm"

    # Bare minimal
    #---
    ensure_packages([
        "${pkgprefix}-cli",
        $fpm_package
    ])
    
    service { $fpm_service:
        ensure  => stopped,
        enable => false,
        require => Package[$fpm_package],
    }
    
    #---
    if $popular_packages {
        ensure_packages([
            'geoip-database-contrib',
            "${pkgprefix}-apcu",
            "${pkgprefix}-curl",
            "${pkgprefix}-gd",
            "${pkgprefix}-geoip",
            "${pkgprefix}-gmp",
            "${pkgprefix}-imagick",
            "${pkgprefix}-imap",
            "${pkgprefix}-intl",
            "${pkgprefix}-json",
            "${pkgprefix}-ldap",
            "${pkgprefix}-mcrypt",
            "${pkgprefix}-msgpack",
            "${pkgprefix}-ssh2",
            "${pkgprefix}-xmlrpc",
        ] + $extra_pkgs, {
            'install_options' => ['--force-yes'],
        })
    }

    #---
    if size($extension) > 0 {
        ensure_packages(
            $extension.map |$v| { "${pkgprefix}-${v}" },
            { 'install_options' => ['--force-yes'] }
        )
    }
}