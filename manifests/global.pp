#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::global (
    Hash[String[1], Hash] $sites = {},
    Hash[String[1], Hash] $keys = {},
    Hash[String[1], Hash] $certs = {},
    Hash[String[1], Hash[String[1], CfWeb::BasicPassword]] $users = {},
    Boolean $ruby = false,
    Boolean $php = false,
    Boolean $nodejs = false,
) {
}
