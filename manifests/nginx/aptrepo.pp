#
# Copyright 2016-2019 (c) Andrey Galkin
#


class cfweb::nginx::aptrepo {
    include cfsystem

    $lsbdistcodename = $::facts['lsbdistcodename']
    $subdir = downcase($::facts['operatingsystem'])
    $release = $::facts['operatingsystem'] ? {
        'Debian' => (versioncmp($::facts['operatingsystemrelease'], '10') >= 0) ? {
            true    => 'stretch',
            default => $lsbdistcodename
        },
        'Ubuntu' => (versioncmp($::facts['operatingsystemrelease'], '18.04') >= 0) ? {
            true    => 'bionic',
            default => $lsbdistcodename
        },
        default  => $lsbdistcodename
    }

    # Nginx official
    #---
    apt::key { 'nginx_signing':
        id      => '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62',
        content => file('cfweb/nginx_signing.key'),
    }

    apt::source { 'nginx':
        location      => "${cfweb::nginx::nginx_repo}/${subdir}/",
        release       => $release,
        repos         => 'nginx',
        pin           => $cfsystem::apt_pin + 1,
        notify_update => false,
        notify        => Exec['cf-apt-update'],
        require       => Apt::Key['nginx_signing'],
    }

}
