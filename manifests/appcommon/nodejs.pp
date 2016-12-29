
define cfweb::appcommon::nodejs(
    String[1] $version = $title,
    Boolean $build_support = false,
) {
    require cfweb::appcommon::nvm

    $nvm_dir = $cfweb::appcommon::nvm::dir

    exec { "Install nodejs: ${title}":
        command     => "/bin/bash -c '. ${nvm_dir}/nvm.sh; nvm install ${version}'",
        unless      => "/bin/bash -c '. ${nvm_dir}/nvm.sh; nvm ls ${version}'",
        user        => $cfweb::appcommon::nvm::user,
        group       => $cfweb::appcommon::nvm::group,
        environment => $cfweb::appcommon::nvm::cmdenv,
        require     => Exec['Setup NVM'],
    }

    if $build_support {
        ensure_packages(['build-essential', 'libssl-dev'],
                        { 'install_options' => ['--force-yes'] })
    }
}
