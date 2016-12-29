
class cfweb::nginx::ubuntu {
    include cfsystem

    case $::cfsystem::ubuntu::release {
        'xenial', 'yakkety': { $release = 'wily' }
        default: { $release = $::cfsystem::ubuntu::release }
    }

    # Nginx official
    #---
    apt::key { 'nginx_signing':
        key     => '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62',
        content => file('cfweb/nginx_signing.key'),
    }

    apt::source { 'nginx':
        location => "${cfweb::nginx::nginx_repo}/ubuntu/",
        release  => $release,
        repos    => 'nginx',
        pin      => $cfsystem::apt_pin + 1,
        require  => Apt::Key['nginx_signing'],
    }

}
