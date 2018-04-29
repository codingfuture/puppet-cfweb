#
# Copyright 2018 (c) Andrey Galkin
#


define cfweb::app::proxy (
    CfWeb::AppCommonParams $common,

    Variant[CfWeb::Upstream,Array[CfWeb::Upstream]] $upstream,
    String[1] $path = '/',
    Optional[String[0]] $uppath = undef,
    Optional[Integer[0]] $keepalive = undef,
) {
    $upstreams = ($upstream =~ Hash) ? {
        true    => [$upstream],
        default => $upstream
    }
    $site = $common['site']
    $app_name = $common['app_name']
    $conf_prefix = $common['conf_prefix']
    $user = $common['user']

    $upname = "app_${site}_${app_name}"

    file { "${conf_prefix}.global.${app_name}":
        mode    => '0640',
        content => epp('cfweb/upstream_proxy', {
            upname    => $upname,
            upstreams => $upstreams,
            keepalive => pick($keepalive, 8),
        }),
    }
    file { "${conf_prefix}.server.${app_name}":
        mode    => '0640',
        content => epp('cfweb/app_proxy', {
            upname => $upname,
            path   => $path,
            uppath => pick_default($uppath, ''),
        }),
    }

    $upstreams.each |$v| {
        if $v['port'] =~ Integer {
            $p = $v['port']
            $s = "proxy_${p}"

            ensure_resource('cfnetwork::describe_service', $s, {
                server => "tcp/${p}",
            })
            ensure_resource('cfnetwork::client_port', "any:${s}:${user}", {
                user => $user,
            })
        }
    }
}
