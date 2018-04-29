#
# Copyright 2018 (c) Andrey Galkin
#


type CfWeb::AppCommonParams = Struct[{
    site           => String[1],
    user           => String[1],
    app_name       => String[1],
    apps           => Array[String[1]],
    site_dir       => String[1],
    conf_prefix    => String[1],
    type           => String[1],
    dbaccess_names => Array[String[1]],
    persistent_dir => String[1],
}]
