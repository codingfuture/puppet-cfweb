#
# Copyright 2018-2019 (c) Andrey Galkin
#


define cfweb::app::multiproxy (
    CfWeb::AppCommonParams $common,

    Hash[String[1], Struct[{
        upstream  => Variant[CfWeb::Upstream,Array[CfWeb::Upstream]],
        keepalive => Optional[Integer[0]],
        uppath    => Optional[String[0]],
    }]] $paths,
) {
    $paths_ext = $paths.reduce($paths) |$m, $v| {
        $k = $v[0]
        $m + {
            "${k}" => $v[1] + {
                app_name => "proxy${k.regsubst(/[^a-zA-Z0-9]/, '_', 'G')}"
            }
        }
    }

    $paths_ext.each |$path, $info| {
        create_resources(
            'cfweb::app::proxy',
            {
                "${title}:${path}" => {
                    common    => $common + {
                        type     => 'proxy',
                        app_name => $info['app_name'],
                    },
                    path      => $path,
                    upstream  => $info['upstream'],
                    keepalive => $info['keepalive'],
                }
            }
        )
    }

    $conf_prefix = $common['conf_prefix']
    $app_name = $common['app_name']

    file { "${conf_prefix}.global.${app_name}":
        mode    => '0640',
        content => ($paths_ext.map |$k, $v| {
            "include ${conf_prefix}.global.${v['app_name']};"
        }).join("\n"),
    }
    file { "${conf_prefix}.server.${app_name}":
        mode    => '0640',
        content => ($paths_ext.map |$k, $v| {
            "include ${conf_prefix}.server.${v['app_name']};"
        }).join("\n"),
    }
}
