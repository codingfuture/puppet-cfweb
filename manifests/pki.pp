#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::pki(
    Integer $dhparam_bits = 2048,

    String $key_name = 'multi',
    Enum['rsa', 'ecdsa'] $key_type = 'rsa',
    Integer[1024] $key_bits = 2048,
    String $key_curve = 'prime256v1',

    String $ssh_user = 'cfwebpki',
    Enum['rsa', 'ed25519'] $ssh_key_type = 'ed25519',
    Integer[1024] $ssh_key_bits = 2048, # for rsa

    Integer[2] $tls_ticket_key_count = 3,
    Integer[60, 1440] $tls_ticket_key_age = 1440,
    Hash $tls_ticket_cron = {
        hour   => '*/3',
        minute => 1
    },

    Optional[Variant[String, Enum['letsencrypt', 'wosign']]]
        $cert_source = undef,
    String[2, 2] $x509_c = 'US',
    String[1] $x509_st = 'Denial',
    String[1] $x509_l = 'Springfield',
    String[1] $x509_o = 'SomeOrg',
    String[1] $x509_ou = 'SomeUnit',

    Array[String] $keys = [],
    Array[String] $certs = [],
) {
    include stdlib
    include cfweb
    include cfweb::pki::user

    #---
    $openssl = '/usr/bin/openssl'
    $root_dir = "${cfweb::pki::user::home_dir}/shared"
    $dhparam = "${root_dir}/dh${dhparam_bits}.pem"
    $ticket_dir = "${root_dir}/tickets"
    $key_dir = "${root_dir}/keys"
    $cert_dir = "${root_dir}/certs"

    include cfweb::pki::dir

    #---
    cfsystem_info { 'cfwebpki':
        ensure => present,
        info   => {
            home => $cfweb::pki::user::home_dir,
            user => $ssh_user,
        }
    }

    #---
    ensure_resource('cfweb::pki::key', $key_name, {
        key_type  => $key_type,
        key_bits  => $key_bits,
        key_curve => $key_curve,
    })
    ensure_resource('cfweb::pki::cert', 'default', {
        key_name => $key_name,
        x509_cn => 'www.example.com',
    })

    #---
    $keys.each |$key_name| {
        create_resources(
                'cfweb::pki::key',
                { $key_name => $cfweb::global::keys[$key_name] }
        )
    }
    $certs.each |$cert_name| {
        create_resources(
                'cfweb::pki::cert',
                { $cert_name => $cfweb::global::cert[$cert_name] }
        )
    }
}
