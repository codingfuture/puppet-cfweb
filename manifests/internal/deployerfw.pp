#
# Copyright 2017 (c) Andrey Galkin
#


define cfweb::internal::deployerfw (
    Hash[String[1], Hash] $fw_ports,
    String[1] $deploy_user = $title,
) {
    # Allow package retrieval
    cfnetwork::client_port { "any:http:${deploy_user}":
        user => $deploy_user,
    }
    cfnetwork::client_port { "any:https:${deploy_user}":
        user => $deploy_user,
    }
    cfnetwork::client_port { "any:ssh:${deploy_user}":
        user => $deploy_user,
    }


    $fw_ports.each |$svc, $def| {
        create_services('cfnetwork::client_port', {
            "any:${svc}:${deploy_user}" => merge($def, {
                user => $deploy_user
            }),
        })
    }
}
