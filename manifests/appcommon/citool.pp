#
# Copyright 2017 (c) Andrey Galkin
#

class cfweb::appcommon::citool(
    String[1] $source = 'https://github.com/futoin/citool',
    Integer[0] $update_cache = 1440,
    Optional[String[1]] $version = undef,
) {
    include cfsystem
    include cfweb::nginx

    $home_dir = "${cfweb::nginx::web_dir}/citool"
    $dir = "${home_dir}/.citool"
    $citool_bin = "${dir}/bin/citool"
    $user = 'citool'
    $group = $cfweb::nginx::group
    $cmdenv = [
        "HTTP_PROXY=${cfsystem::http_proxy}",
        "HTTPS_PROXY=${cfsystem::http_proxy}",
    ]
    $git_proxy = $cfsystem::http_proxy ? {
        undef => '',
        '' => '',
        default   => "-c 'http_proxy=${cfsystem::http_proxy}'"
    }

    if $git_proxy != '' {
        cfnetwork::client_port{ "any:aptproxy:cfweb${user}":
            dst  => $::cfsystem::repo_proxy['host'],
            user => $user,
        }
    } else {
        cfnetwork::client_port{ 'any:http:cfsystem': user => $user }
        cfnetwork::client_port{ 'any:https:cfsystem': user => $user }
    }

    $update_onlyif_main = "/usr/bin/find '${dir}/.git/FETCH_HEAD' -mmin '+${update_cache}' | /bin/egrep '.'"
    $update_onlyif = $version ? {
        undef   => $update_onlyif_main,
        default => [
            "/usr/bin/git describe --abbrev=0 --tags --match '${version}' origin",
            $update_onlyif_main
        ].join(' && ')
    }

    user { $user:
        ensure     => present,
        gid        => $group,
        home       => $home_dir,
        managehome => true,
        require    => Group[$group],
    } ->
    exec { 'Setup CITool':
        command     => "/usr/bin/git ${git_proxy} clone '${source}' '${dir}'",
        creates     => $citool_bin,
        user        => $user,
        group       => $group,
        cwd         => $home_dir,
        environment => $cmdenv,
        notify      => Exec['Checkout CITool'],
        require     => Anchor['cfnetwork:firewall'],
        loglevel    => 'warning',
    } ->
    exec { 'Update CITool':
        command     => "/usr/bin/git ${git_proxy} fetch origin",
        user        => $user,
        group       => $group,
        cwd         => $dir,
        environment => $cmdenv,
        onlyif      => $update_onlyif,
        notify      => Exec['Checkout CITool'],
        require     => Anchor['cfnetwork:firewall'],
        loglevel    => 'warning',
    }

    $citool_checkout = $version ? {
        undef   => "/usr/bin/git checkout $(/usr/bin/git describe --abbrev=0 --tags --match 'v[0-9]*' origin)",
        default => "/usr/bin/git checkout ${version}",
    }

    exec { 'Checkout CITool':
        command     => $citool_checkout,
        user        => $user,
        group       => $group,
        cwd         => $dir,
        refreshonly => true,
        loglevel    => 'warning',
    }
}
