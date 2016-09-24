
define cfweb::pki::key(
    $key_name = $title,
    $key_bits = undef,
){
    include cfweb::pki
    
    $exec_name = "cfweb::pki::key::${key_name}"
    $key_file = "${cfweb::pki::key_dir}/${key_name}.key"
    
    if $cfweb::is_secondary {
        exec { $exec_name:
            command => '/bin/true',
            creates => $key_file,
            notify => Exec['cfweb_sync_pki']
        }
    } else {
        exec { $exec_name:
            command => [
                "${cfweb::pki::openssl} genrsa",
                '-out', $key_file,
                pick($key_bits, $cfweb::pki::key_bits)
            ].join(' '),
            creates => $key_file,
            notify => Exec['cfweb_sync_pki']
        }
    }
}
