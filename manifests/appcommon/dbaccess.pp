#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::appcommon::dbaccess(
    String[1] $cluster,
    String[1] $role,
    String[1] $local_user,
    Hash[String[1], Any] $config_vars,
) {}
