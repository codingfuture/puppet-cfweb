
class cfweb::pki(
    $dhparam_bits = 2048,
    $key_bits = 2048,
    
    $ssh_user = 'cfwebpki',
    $ssh_key_type = 'ed25519',
    $ssh_key_bits = 2048, # for rsa
) {
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
    $root_dir = "${cfweb::pki::user::home_dir}/shared"
    $dhparam = "${root_dir}/dh${dhparam_bits}.pem"
    $ticket_dir = "${root_dir}/tickets"
    $vhost_dir = "${root_dir}/vhosts"
    
    include cfweb::pki::dir
    include cfweb::pki::cron
    
    #---
    cfsystem_info { 'cfwebpki':
        ensure => present,
        info => {
            home => $cfweb::pki::user::home_dir,
            user => $ssh_user,
        }
    }
}
