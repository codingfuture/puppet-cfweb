#
# Copyright 2017 (c) Andrey Galkin
#


define cfweb::nginx::group(
    String[1] $group = $title,
) {
    include cfweb::nginx

    exec { "add_nginx_to_${group}":
        command => "/usr/sbin/adduser ${cfweb::nginx::user} ${group}",
        unless  => "/usr/bin/id -Gn ${cfweb::nginx::user} | /bin/grep -q ${group}",
        require => Group[$group],
        notify  => Exec['cfweb_reload'],
    }
}
