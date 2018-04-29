#
# Copyright 2017-2018 (c) Andrey Galkin
#


define cfweb::internal::deployerfw (
    Hash[String[1], Hash] $fw_ports,
    String[1] $deploy_group,
) {
    # Allow package retrieval
    ensure_resources(
        'cfnetwork::client_port',
        {
            "any:http:${deploy_group}" => {
                group => $deploy_group,
            },
            "any:https:${deploy_group}" => {
                group => $deploy_group,
            },
            "any:cfssh:${deploy_group}" => {
                group => $deploy_group,
            },
        }
    )

    $fw_ports.each |$svc, $def| {
        ensure_resource(
            'cfnetwork::client_port',
            "any:${svc}:${deploy_group}",
            ($def + {
                group => $deploy_group
            }),
        )
    }
}
