#
# Copyright 2017 (c) Andrey Galkin
#


function cfweb::certinfo(String[1] $cert_name) >> Hash {
    $crt_file = "${cfweb::pki::cert_dir}/${cert_name}.crt"

    if $cert_name == 'default' {
        $cert = {}
    } else {
        $cert = $cfweb::global::certs[$cert_name]
    }

    if !$cert {
        fail("Please make sure Cfweb::Pki::Cert[${cert_name}] is defined")
    }

    if $cert['cert_source'] {
        $trusted_file = "${crt_file}.trusted"
    } else {
        $trusted_file = undef
    }

    $key_name = pick($cert['key_name'], $cfweb::pki::key_name)

    ({
        cert_name    => $cert_name,
        key_file     => "${cfweb::pki::key_dir}/${key_name}.key",
        crt_file     => $crt_file,
        trusted_file => $trusted_file,
    })
}
