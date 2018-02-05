#
# Copyright 2017-2018 (c) Andrey Galkin
#


define cfweb::internal::deployerfw (
    Hash[String[1], Hash] $fw_ports,
    String[1] $deploy_group = $title,
) {
    # Allow package retrieval
    cfnetwork::client_port { "any:http:${deploy_group}":
        group => $deploy_group,
    }
    cfnetwork::client_port { "any:https:${deploy_group}":
        group => $deploy_group,
    }
    cfnetwork::client_port { "any:ssh:${deploy_group}":
        group => $deploy_group,
    }


    $fw_ports.each |$svc, $def| {
        if !defined( Cfnetwork::Client_port["any:${svc}:${deploy_group}"] ) {
            create_resources('cfnetwork::client_port', {
                "any:${svc}:${deploy_group}" => merge($def, {
                    group => $deploy_group
                }),
            })
        }
    }
}
