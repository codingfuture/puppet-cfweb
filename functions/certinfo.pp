#
# Copyright 2017 (c) Andrey Galkin
#


function cfweb::certinfo(String[1] $cert_name) >> Hash {
    $crt_file = "${cfweb::pki::cert_dir}/${cert_name}.crt"

    if $cert_name == 'default' {
        $cert = {}
        $trusted_file = undef
    } else {
        $cert = $cfweb::global::certs[$cert_name]
        $trusted_file = "${crt_file}.trusted"
    }

    if !$cert {
        fail("Please make sure Cfweb::Pki::Cert[${cert_name}] is defined")
    }

    $key_name = pick($cert['key_name'], $cfweb::pki::key_name)

    ({
        cert_name    => $cert_name,
        key_file     => "${cfweb::pki::key_dir}/${key_name}.key",
        crt_file     => $crt_file,
        trusted_file => $trusted_file,
    })
}
