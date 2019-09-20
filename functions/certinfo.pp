#
# Copyright 2017-2019 (c) Andrey Galkin
#


function cfweb::certinfo(String[1] $cert_name) >> Hash {
    if $cert_name == 'default' {
        $cert = {}
        $cert_name_act = $cert_name
        $def_key_name = $cfweb::pki::rsa_key_name
    } elsif $cert_name == 'defaultec' {
        $cert = {}
        $cert_name_act = $cert_name
        $def_key_name = $cfweb::pki::ecc_key_name
    } elsif $cert_name =~ /^auto(ec)?#/ {
        $cert_source = pick_default(
            getparam(Cfweb::Pki::Cert[$cert_name], 'cert_source'),
            $cfweb::pki::cert_source
        )

        $cn1 = $cert_name.regsubst(/^auto(ec)?#/, '')

        if $cert_name =~ /^autoec#/ {
            $cn2 = '_ecc'
            $def_key_name = $cfweb::pki::ecc_key_name
        } else {
            $cn2 = ''
            $def_key_name = $cfweb::pki::rsa_key_name
        }

        $cert_name_act = "${cn1}${cn2}"
        $cert = {
            cert_source => $cert_source
        }
    } else {
        $cert = $cfweb::global::certs[$cert_name]
        $cert_name_act = $cert_name
        $def_key_name = $cfweb::pki::rsa_key_name
    }

    if !$cert {
        fail("Please make sure Cfweb::Pki::Cert[${cert_name}] is defined")
    }

    $crt_file = "${cfweb::pki::cert_dir}/${cert_name_act}.crt"

    if $cert['cert_source'] {
        $trusted_file = "${crt_file}.trusted"
    } else {
        $trusted_file = undef
    }

    $key_name = pick($cert['key_name'], $def_key_name)

    ({
        cert_name    => $cert_name,
        key_file     => "${cfweb::pki::key_dir}/${key_name}.key",
        crt_file     => $crt_file,
        trusted_file => $trusted_file,
    })
}
