#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::appcommon::rubygem(
    String[1] $package,
    String[1] $ruby,
) {
    require cfweb::appcommon::rvm

    $rvm_bin = $cfweb::appcommon::rvm::rvm_bin

    exec { "Installing ${title} gem ${package}":
        command     => '/bin/true',
        unless      => "${rvm_bin} ${ruby} do gem list --local '^${package}\$' | /bin/grep ${package}",
        user        => $cfweb::appcommon::rvm::user,
        group       => $cfweb::appcommon::rvm::group,
        environment => $cfweb::appcommon::rvm::cmdenv,
        cwd         => $cfweb::appcommon::rvm::home_dir,
        loglevel    => 'warning',
    }
    ~> exec { "Installed ${title} gem ${package}":
        command     => "${rvm_bin} ${ruby} do gem install --no-ri --no-doc ${package}",
        refreshonly => true,
        user        => $cfweb::appcommon::rvm::user,
        group       => $cfweb::appcommon::rvm::group,
        environment => $cfweb::appcommon::rvm::cmdenv,
        cwd         => $cfweb::appcommon::rvm::home_dir,
        loglevel    => 'warning',
    }
}
