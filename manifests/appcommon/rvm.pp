
class cfweb::appcommon::rvm(
    String[1] $source = 'https://get.rvm.io',
    Integer[0] $update_cache = 1440,
    String[1] $version = 'stable',
    Boolean $build_support = true,
) {
    include cfsystem
    include cfweb::nginx

    $home_dir = "${cfweb::nginx::web_dir}/rvm"
    $dir = "${home_dir}/.rvm"
    $rvm_bin = "${dir}/bin/rvm"
    $user = 'rvm'
    $group = $cfweb::nginx::group
    $cmdenv = [
        "HTTP_PROXY=${cfsystem::http_proxy}",
        "HTTPS_PROXY=${cfsystem::http_proxy}",
        "HOME=${home_dir}",
    ]

    if $cfsystem::http_proxy != '' {
        cfnetwork::client_port{ "any:aptproxy:cfweb${user}":
            dst  => $::cfsystem::repo_proxy['host'],
            user => $user,
        }
    } else {
        cfnetwork::client_port{ 'any:http:cfsystem': user => $user }
        cfnetwork::client_port{ 'any:https:cfsystem': user => $user }
    }

    user { $user:
        ensure     => present,
        gid        => $group,
        home       => $home_dir,
        managehome => true,
        require    => Group[$group],
    } ->
    exec { 'Setup RVM GPG':
        command     => '/usr/bin/curl -sSL https://rvm.io/mpapis.asc | /usr/bin/gpg2 --import -',
        user        => $user,
        group       => $group,
        cwd         => $home_dir,
        environment => $cmdenv,
        unless      => '/usr/bin/gpg2 --list-keys 409B6B1796C275462A1703113804BB82D39DC0E3',
    } ->
    exec { 'Setup RVM':
        command     => "/usr/bin/curl -sSL '${source}' | bash -s ${version}",
        user        => $user,
        group       => $group,
        cwd         => $home_dir,
        environment => $cmdenv,
        unless      => "/usr/bin/test -e ${rvm_bin}",
    } ->
    exec { 'Update RVM':
        command     => "${rvm_bin} get ${version} --auto",
        user        => $user,
        group       => $group,
        cwd         => $home_dir,
        environment => $cmdenv,
        onlyif      => "/usr/bin/find '${dir}/installed.at' -mmin '+${update_cache}' | /bin/egrep '.'",
    }

    $build_essentials = [
        'bison',
        'build-essential',
        'libssl-dev',
        'zlib1g-dev',
        'libreadline-gplv2-dev',
        'libxml2-dev',
    ]

    if $build_support {
        ensure_packages($build_essentials, { 'install_options' => ['--force-yes'] })
    }

}
