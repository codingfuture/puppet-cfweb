
define cfweb::appcommon::rubygem(
    String[1] $package,
    String[1] $ruby,
) {
    require cfweb::appcommon::rvm

    $rvm_bin = $cfweb::appcommon::rvm::rvm_bin

    exec { "Install ${title} gem ${package}":
        command     => "${rvm_bin} ${ruby} do gem install ${package}",
        unless      => "${rvm_bin} ${ruby} do gem list --local '^${package}\$' | /bin/grep ${package}",
        user        => $cfweb::appcommon::rvm::user,
        group       => $cfweb::appcommon::rvm::group,
        environment => $cfweb::appcommon::rvm::cmdenv,
        cwd         => $cfweb::appcommon::rvm::home_dir,
    }
}
