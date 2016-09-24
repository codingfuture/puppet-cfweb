
define cfweb::pki::cert(
    $cert_name = $title,
    $key_name,
    $cert_source = undef,
    $x509_C = undef,
    $x509_ST = undef,
    $x509_L = undef,
    $x509_O = undef,
    $x509_CN = undef,
){
    include cfweb::pki
    
    $exec_name = "cfweb::pki::cert::${cert_name}"
    $key_file = "${cfweb::pki::key_dir}/${key_name}.key"
    $cert_base = "${cfweb::pki::cert_dir}/${cert_name}"
    $crt_file = "${cert_base}.crt"
    $csr_file = "${cert_base}.csr"
    
    if $cfweb::is_secondary {
        exec { $exec_name:
            command => '/bin/true',
            creates => $crt_file,
            notify => Exec['cfweb_sync_pki']
        }
    } else {
        $x_C = pick($x509_C, $cfweb::pki::x509_C)
        $x_ST = pick($x509_ST, $cfweb::pki::x509_ST)
        $x_L = pick($x509_L, $cfweb::pki::x509_L)
        $x_O = pick($x509_O, $cfweb::pki::x509_O)
        $x_CN = pick($x509_CN, $cert_name)
        
        # CSR must always be available
        exec { "${exec_name}::csr":
            command => [
                "${cfweb::pki::openssl} req",
                "-out ${csr_file}",
                "-key ${key_file}",
                "-new -sha256",
                "-subj '/C=${x_C}/ST=${x_ST}/L=${x_L}/O=${x_O}/CN=${x_CN}'",
            ].join(' '),
            creates => $csr_file,
            notify => Exec['cfweb_sync_pki']
        }
        
        if pick_default($cert_source, $cfweb::pki::cert_source) == 'letsencrypt' {
            fail('TODO: implement letsencrypt support')
        } elsif $cert_source {
            file { $crt_file:
                content => file($cert_source),
                notify => Exec['cfweb_sync_pki'],
            }
        } else {
            exec { $exec_name:
                command => [
                    "${cfweb::pki::openssl} x509",
                    '-req -days 3650',
                    "-in ${csr_file}",
                    "-signkey ${key_file}",
                    "-out ${crt_file}",
                ].join(' '),
                creates => $crt_file,
                notify => Exec['cfweb_sync_pki']
            }
        }
    }
}
