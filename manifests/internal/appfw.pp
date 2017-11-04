#
# Copyright 2017 (c) Andrey Galkin
#


define cfweb::internal::appfw (
    Hash[String[1], Hash] $fw_ports,
    String[1] $app_user = $title,
) {
    $fw_ports.each |$svc, $def| {
        create_services('cfnetwork::client_port', {
            "any:${svc}:${app_user}" => merge($def, {
                user => $app_user
            }),
        })
    }
}
