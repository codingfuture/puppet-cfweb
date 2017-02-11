#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::appcommon::nodejs(
    String[1] $version = $title,
    Boolean $build_support = false,
) {
    require cfweb::appcommon::nvm

    $nvm_env_sh = $cfweb::appcommon::nvm::env_sh

    exec { "Installing nodejs: ${title}":
        command     => '/bin/true',
        unless      => "/bin/bash -c '. ${nvm_env_sh}; nvm ls ${version}'",
        user        => $cfweb::appcommon::nvm::user,
        group       => $cfweb::appcommon::nvm::group,
        environment => $cfweb::appcommon::nvm::cmdenv,
        require     => Exec['Setup NVM'],
        loglevel    => 'warning',
    } ~>
    exec { "Installed nodejs: ${title}":
        command     => "/bin/bash -c '. ${nvm_env_sh}; nvm install ${version}'",
        refreshonly => true,
        user        => $cfweb::appcommon::nvm::user,
        group       => $cfweb::appcommon::nvm::group,
        environment => $cfweb::appcommon::nvm::cmdenv,
        require     => Exec['Setup NVM'],
        loglevel    => 'warning',
    }

    if $build_support {
        ensure_packages(['build-essential', 'libssl-dev'],
                        { 'install_options' => ['--force-yes'] })
    }
}
