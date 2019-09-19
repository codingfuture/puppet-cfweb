#
# Copyright 2016-2019 (c) Andrey Galkin
#


class cfweb::pki(
    String[2, 2] $x509_c,
    String[1] $x509_st,
    String[1] $x509_l,
    String[1] $x509_o,
    String[1] $x509_ou,
    String[1] $x509_email,

    Integer[1024, 8192] $dhparam_bits = 2048,

    String[1] $rsa_key_name = 'multi',
    Cfsystem::Rsabits $rsa_bits = 2048,
    String[1] $ecc_key_name = 'multiec',
    String[1] $ecc_curve = 'prime256v1',
    String[1] $cert_hash = 'sha256',

    String $ssh_user = 'cfwebpki',
    Cfsystem::Keytype
        $ssh_key_type = 'ed25519',
    Cfsystem::Rsabits
        $ssh_key_bits = 2048, # for rsa

    Integer[2] $tls_ticket_key_count = 3,
    Integer[60, 1440] $tls_ticket_key_age = 1440,
    Hash $tls_ticket_cron = {
        hour   => '*/3',
        minute => 1
    },

    Optional[Variant[String[1], Enum['acme']]]
        $cert_source = undef,
) {
    anchor { 'cfweb::pki:dyn_setup': }

    #---
    include stdlib
    include cfweb
    include cfweb::pki::user

    #---
    $enable = $cfweb::nginx::enable
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
    ensure_resource('cfweb::pki::key', $rsa_key_name, {
        key_type  => 'rsa',
        rsa_bits  => $rsa_bits,
    })
    ensure_resource('cfweb::pki::key', $ecc_key_name, {
        key_type  => 'ecdsa',
        ecc_curve  => $ecc_curve,
    })
    ensure_resource('cfweb::pki::cert', 'default', {
        key_name => $rsa_key_name,
        x509_cn => 'www.example.com',
    })
    ensure_resource('cfweb::pki::cert', 'defaultec', {
        key_name => $ecc_key_name,
        x509_cn => 'www.example.com',
    })
}
