
class cfweb::pki(
    $dhparam_bits = 2048,
    
    $key_name = 'multi',
    $key_type = 'rsa',
    $key_bits = 2048,
    $key_curve = 'prime256v1',
    
    $ssh_user = 'cfwebpki',
    $ssh_key_type = 'ed25519',
    $ssh_key_bits = 2048, # for rsa
    
    $tls_ticket_key_count = 3,
    $tls_ticket_key_age = 1440,
    $tls_ticket_cron = {
        hour   => '*/3',
        minute => 1
    },
    
    $cert_source = undef,
    $x509_C = 'US',
    $x509_ST = 'Denial',
    $x509_L = 'Springfield',
    $x509_O = 'SomeOrg',
) {
    include stdlib

    $cluster = $cfweb::cluster
    
    $host_facts = cf_query_facts("cfweb.cluster=\"${cluster}\"", ['cfweb'])
    $cluster_hosts = $host_facts.reduce({}) |$memo, $val| {
        $host = $val[0]
        $cluster_info = $val[1]['cfweb']
        merge($memo, {
            $host => $cluster_info
        })
    }
    
    $primary_host = $cluster_hosts.reduce('') |$memo, $val| {
        if $val[1]['is_secondary'] {
            $memo
        } else {
            $val[0]
        }
    }
    
    if $primary_host != '' and 
       $primary_host != $::trusted['certname'] and
       $cfweb::is_secondary != true
    {
        fail([ "Primary cfweb host for ${cluster} is already known: ${primary_host}.",
               'Please consider setting cfweb::is_secondary'].join("\n"))
    }
    
    #---
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
        info => {
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
        x509_CN => 'www.example.com',
    })
}
