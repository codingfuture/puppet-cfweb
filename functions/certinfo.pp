#
# Copyright 2017 (c) Andrey Galkin
#


function cfweb::certinfo(String[1] $cert_name) >> Hash {
    $crt_file = "${cfweb::pki::cert_dir}/${cert_name}.crt"

    if $cert_name == 'default' {
        $cert = {}
    } elsif $cert_name =~ /^auto__/ {
        $cert_source = pick_default(
            getparam(Cfweb::Pki::Cert[$cert_name], 'cert_source'),
            $cfweb::pki::cert_source
        )
        $cert = {
            cert_source => $cert_source
        }
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
