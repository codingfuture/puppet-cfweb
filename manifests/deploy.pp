#
# Copyright 2016-2019 (c) Andrey Galkin
#


define cfweb::deploy(
    String[1] $strategy,
    Hash[String[1], Any] $params,
    CfWeb::AppCommonParams $common,
) {
    include cfweb::internal::deployuser

    assert_private()

    case $strategy {
        'futoin', 'docker' : {
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
                common => $common,
            }
        },
        $params
    )
}
