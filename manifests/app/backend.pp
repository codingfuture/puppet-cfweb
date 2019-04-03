#
# Copyright 2019 (c) Andrey Galkin
#


define cfweb::app::backend (
    CfWeb::AppCommonParams $common,

    String[1] $site,
) {
    $sites_raw = cfsystem::query([
        'from', 'resources', ['extract', [ 'certname', 'parameters' ],
            ['and',
                ['=', 'type', 'Cfweb::Internal::Backend'],
                ['=', 'title', $site],
                ['=', ['parameter', 'location'], $cfsystem::hierapool::location],
                ['=', ['parameter', 'pool'], $cfsystem::hierapool::pool],
            ],
        ],
        ['order_by', [['certname', 'asc']]],
    ])

    if $sites_raw.empty {
        fail("Failed to find backend for ${site}")
    }

    $upstreams = $sites_raw.map |$v| {
        $params = $v['parameters']

        $r = {
            host => $params['host'],
            port => $params['port'],
        }
        $r
    }

    $upname_tmp = sha256(($upstreams.map |$v| {
        $host = $v['host'].regsubst('.', '_', 'G')
        $port = $v['port']
        "${host}_${port}"
    }).join('__'))
    $upname = "common_${upname_tmp}"
    $upfile = "${cfweb::nginx::sites_dir}/upstream.${upname}.conf"

    ensure_resource('file', $upfile, {
        mode    => '0640',
        content => epp('cfweb/upstream_proxy', {
            upname    => $upname,
            upstreams => $upstreams,
            keepalive => 128,
        }),
    })
    $upstreams.each |$v| {
        if $v['port'] =~ Integer {
            $p = $v['port']
            $s = "proxy_${p}"

            ensure_resource('cfnetwork::describe_service', $s, {
                server => "tcp/${p}",
            })
            $upstreams.each |$v| {
                $h = $v['host']
                ensure_resource('cfnetwork::client_port', "any:${s}:cfnginx-${h}", {
                    user => $cfweb::nginx::user,
                    dst => $h,
                })
            }
        }
    }

    #---
    $app_name = $common['app_name']
    $conf_prefix = $common['conf_prefix']

    file { "${conf_prefix}.global.${app_name}":
        mode    => '0640',
        content => '',
    }
    file { "${conf_prefix}.server.${app_name}":
        mode    => '0640',
        content => epp('cfweb/app_proxy', {
            upname => $upname,
            path   => '/',
            uppath => '',
        }),
    }
}
