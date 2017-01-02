#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::appcommon::nvm(
    String[1] $source = 'https://github.com/creationix/nvm.git',
    Integer[0] $update_cache = 1440,
    Optional[String[1]] $version = undef,
) {
    include cfsystem
    include cfweb::nginx

    $home_dir = "${cfweb::nginx::web_dir}/nvm"
    $dir = "${home_dir}/nvm"
    $user = 'nvm'
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
    exec { 'Setup NVM':
        command     => "/usr/bin/git ${git_proxy} clone '${source}' '${dir}'",
        creates     => $dir,
        user        => $user,
        group       => $group,
        environment => $cmdenv,
        notify      => Exec['Checkout NVM'],
    } ->
    exec { 'Update NVM':
        command     => "/usr/bin/git ${git_proxy} fetch origin",
        user        => $user,
        group       => $group,
        cwd         => $dir,
        environment => $cmdenv,
        onlyif      => $update_onlyif,
        notify      => Exec['Checkout NVM'],
    }

    exec { 'Checkout NVM':
        command     => $version ? {
            undef   => "/usr/bin/git checkout $(/usr/bin/git describe --abbrev=0 --tags --match 'v[0-9]*' origin)",
            default => "/usr/bin/git checkout ${version}",
        },
        user        => $user,
        group       => $group,
        cwd         => $dir,
        refreshonly => true,
    }
}
