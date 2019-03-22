#
# Copyright 2018-2019 (c) Andrey Galkin
#

define cfweb::internal::clientpki {
    include cfweb::global
    include cfweb::nginx

    $clientpki_dir = $cfweb::nginx::clientpki_dir
    $group = $cfweb::nginx::group
    $source = $cfweb::global::clientpki[$title]

    if empty($source) {
        fail("Missing \$cfweb::global::clientpki[${title}]")
    }

    if empty($source['ca']) == empty($source['ca_source']) {
        fail("Define either 'ca' or 'ca_source' for \$cfweb::global::clientpki[${title}]")
    }
    if !empty($source['crl']) and !empty($source['crl_source']) {
        fail("Define either 'crl' or 'crl_source' for \$cfweb::global::clientpki[${title}]")
    }

    #---
    $ca_method = !empty($source['ca']) ? {
        true    => content,
        default => source,
    }
    $crl = pick_default($source['crl'], $source['crl_source'])

    if empty($crl) {
        $crl_def = {}
    } else {
        $crl_method = !empty($source['crl']) ? {
            true    => content,
            default => source,
        }
        $crl_def = {
            "${clientpki_dir}/${title}.crl.pem" => {
                "${crl_method}" => $crl,
            }
        }
    }

    create_resources(
        'file',
        merge({
            "${clientpki_dir}/${title}.ca.pem"  => {
                "${ca_method}" => pick($source['ca'], $source['ca_source']),
            },
        }, $crl_def),
        {
            group          => $group,
            mode           => '0640',
        }
    )
}
