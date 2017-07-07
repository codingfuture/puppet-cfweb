#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::appcommon::php(
    Boolean $popular_packages = true,
    Array[String] $extension = [],
) {
    $is_v7 = $::facts['operatingsystem'] ? {
        'Debian' => (versioncmp($::facts['operatingsystemrelease'], '9') >= 0),
        'Ubuntu' => (versioncmp($::facts['operatingsystemrelease'], '16.04') >= 0),
        default  => false
    }

    if $is_v7 {
        $php_ver = '7.0' # TODO: fact
        $pkgprefix = 'php'
        $php_etc_root = "/etc/php/${php_ver}"
        $fpm_service = "php${php_ver}-fpm"
        $fpm_package = 'php-fpm'

        $extra_pkgs = [
            'php-apcu',
            'php-bcmath',
            'php-bz2',
            'php-curl',
            'php-gd',
            'php-geoip',
            'php-gmp',
            'php-imagick',
            'php-imap',
            'php-intl',
            'php-json',
            'php-ldap',
            'php-mbstring',
            'php-mcrypt',
            'php-msgpack',
            'php-opcache',
            'php-ssh2',
            'php-soap',
            'php-xml',
            'php-xmlrpc',
            'php-xsl',
            'php-zip',
        ]
    } else {
        $pkgprefix = 'php5'
        $php_etc_root = '/etc/php5'
        $fpm_service = "${pkgprefix}-fpm"
        $fpm_package = "${pkgprefix}-fpm"
        $extra_pkgs = [
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
        ]
    }

    # Bare minimal
    #---
    ensure_packages([
        "${pkgprefix}-cli",
        $fpm_package
    ])

    service { $fpm_service:
        ensure   => stopped,
        enable   => false,
        provider => 'systemd',
        require  => Package[$fpm_package],
    }

    #---
    if $popular_packages {
        ensure_packages([
            'geoip-database-contrib',
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
