#
# Copyright 2017-2019 (c) Andrey Galkin
#


define cfweb::internal::appfw (
    Hash[String[1], Hash] $fw_ports,
    String[1] $app_user,
) {
    $fw_ports.each |$svc, $def| {
        create_resources('cfnetwork::client_port', {
            "any:${svc}:${app_user}" => merge($def, {
                user => $app_user
            }),
        })
    }
}
