#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::deploy(
    String[1] $strategy,
    Hash[String[1], Any] $params,
    String[1] $site,
    String[1] $run_user,
    String[1] $deploy_user,
    String[1] $site_dir,
    String[1] $persistent_dir,
    Array[String[1]] $apps,
) {
    include cfweb::internal::deployuser

    assert_private()

    case $strategy {
        'futoin' : {
            $impl = "cfweb::deploy::${strategy}"
        }
        default : {
            $impl = $strategy
        }
    }

    create_resources(
        $impl,
        {
            $title => {
                site => $site,
                run_user => $run_user,
                deploy_user => $deploy_user,
                site_dir => $site_dir,
                persistent_dir => $persistent_dir,
                apps => $apps,
            }
        },
        $params
    )
}
