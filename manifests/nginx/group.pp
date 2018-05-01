#
# Copyright 2017-2018 (c) Andrey Galkin
#


define cfweb::nginx::group(
    String[1] $group = $title,
) {
    include cfweb::nginx

    cfsystem::add_group($cfweb::nginx::user, $group)
    ~> Exec['cfweb_reload']
}
