#
# Copyright 2016-2018 (c) Andrey Galkin
#


class cfweb::global (
    Hash[String[1], Hash] $sites = {},
    Hash[String[1], Hash] $keys = {},
    Hash[String[1], Hash] $certs = {},
    Hash[String[1], Hash[String[1], CfWeb::BasicPassword]] $users = {},
    Hash[String[1], Array[String[1]]] $hosts = {},
    Boolean $ruby = true,
    Boolean $php = true,
    Boolean $nodejs = true,
) {
}
