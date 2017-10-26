#
# Copyright 2017 (c) Andrey Galkin
#


class cfweb::pki::acme(
    Boolean $staging = false,
) {
    include cfweb::pki::user

    # Command to use in cert
    #---
    include cfsystem::custombin
    $command = "${cfsystem::custombin::bin_dir}/cfweb_acme_sign"

    file { $command:
        mode    => '0500',
        content => epp('cfweb/cfweb_acme_sign.epp'),
    }

    # ACME requests
    #---
    $user = $cfweb::pki::user::user

    cfnetwork::client_port { "any:https:${user}-acme":
        user => $user,
    }

}
