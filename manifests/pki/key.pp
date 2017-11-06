#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::pki::key(
    String[1] $key_name = $title,
    Optional[Enum['rsa', 'ecdsa']] $key_type = undef,
    Optional[Cfsystem::Rsabits] $key_bits = undef,
    Optional[String[1]] $key_curve = undef,
){
    include cfweb::pki

    $exec_name = "cfweb::pki::key::${key_name}"
    $key_file = "${cfweb::pki::key_dir}/${key_name}.key"

    if $cfweb::is_secondary {
        exec { $exec_name:
            command => '/bin/true',
            creates => $key_file,
            notify  => Exec['cfweb_sync_pki']
        }
    } else {
        $key_type_act = pick($key_type, $cfweb::pki::key_type)

        case $key_type_act {
            'rsa': {
                exec { $exec_name:
                    command => [
                        "${cfweb::pki::openssl} genrsa",
                        '-out', $key_file,
                        pick($key_bits, $cfweb::pki::key_bits)
                    ].join(' '),
                    creates => $key_file,
                    notify  => Exec['cfweb_sync_pki'],
                    require => File[$cfweb::pki::key_dir],
                }
            }
            'ecdsa': {
                exec { $exec_name:
                    command => [
                        "${cfweb::pki::openssl} ecparam",
                        '-name',
                        pick($key_curve, $cfweb::pki::key_curve),
                        '-genkey -noout',
                        '-out', $key_file,
                    ].join(' '),
                    creates => $key_file,
                    notify  => Exec['cfweb_sync_pki'],
                    require => File[$cfweb::pki::key_dir],
                }
            }
            default: {
                fail("Not supported key type ${key_type_act} for ${key_name}")
            }
        }

        #---
        $pki_user = $cfweb::pki::ssh_user

        Exec[$exec_name]
        -> file { $key_file:
            owner   => $pki_user,
            group   => $pki_user,
            mode    => '0640',
            replace => no,
            content => '',
        }
    }
}
