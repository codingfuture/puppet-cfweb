
class cfweb::nginx::debian {
    include cfsystem

    # Nginx official
    #---
    apt::key { 'nginx_signing':
        key => '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62',
        content => file('cfweb/nginx_signing.key'),
    }

    apt::source { 'nginx':
        location => 'http://nginx.org/packages/mainline/debian/',
        release  => $::cfsystem::debian::release,
        repos    => 'nginx',
        pin      => $cfsystem::apt_pin + 1,
        require => Apt::Key['nginx_signing'],
    }

}
