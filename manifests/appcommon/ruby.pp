#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::appcommon::ruby(
    String[1] $version = $title,
    Boolean $build_support = false,
) {
    require cfweb::appcommon::rvm

    $rvm_dir = $cfweb::appcommon::rvm::dir
    $rvm_bin = $cfweb::appcommon::rvm::rvm_bin

    if $build_support {
        ensure_packages($cfweb::appcommon::rvm::build_essentials,
                        { 'install_options' => ['--force-yes'] })
    }

    exec { "Installing ruby ${title}":
        command     => '/bin/true',
        unless      => "${rvm_bin} ${version} do ruby -v",
        user        => $cfweb::appcommon::rvm::user,
        group       => $cfweb::appcommon::rvm::group,
        environment => $cfweb::appcommon::rvm::cmdenv,
        cwd         => $cfweb::appcommon::rvm::home_dir,
        require     => Exec['Setup RVM'],
        loglevel    => 'warning',
    }
    ~> exec { "Installed ruby: ${title}":
        command     => "${rvm_bin} autolibs disable; ${rvm_bin} install ${version}",
        refreshonly => true,
        user        => $cfweb::appcommon::rvm::user,
        group       => $cfweb::appcommon::rvm::group,
        environment => $cfweb::appcommon::rvm::cmdenv,
        cwd         => $cfweb::appcommon::rvm::home_dir,
        require     => Exec['Setup RVM'],
        loglevel    => 'warning',
    }
    -> cfweb::appcommon::rubygem{ "${title}:bundler":
        package => 'bundler',
        ruby    => $version,
    }
    -> cfweb::appcommon::rubygem{ "${title}:faye-websocket":
        package => 'faye-websocket',
        ruby    => $version,
    }
    -> cfweb::appcommon::rubygem{ "${title}:puma":
        package => 'puma',
        ruby    => $version,
    }
}
