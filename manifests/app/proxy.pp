#
# Copyright 2018 (c) Andrey Galkin
#


define cfweb::app::proxy (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,

    Variant[CfWeb::Upstream,Array[CfWeb::Upstream]] $upstream,
    Integer[0] $keepalive = 8,
) {
    $upstreams = ($upstream =~ Hash) ? {
        true    => [$upstream],
        default => $upstream
    }

    file { "${conf_prefix}.global.proxy":
        mode    => '0640',
        content => epp('cfweb/upstream_proxy', {
            site      => $site,
            upstreams => $upstreams,
            keepalive => $keepalive,
        }),
    }
    file { "${conf_prefix}.server.proxy":
        mode    => '0640',
        content => epp('cfweb/app_proxy', {
            site            => $site,
        }),
    }

    $upstreams.each |$v| {
        if $v['port'] =~ Integer {
            $p = $v['port']
            $s = "app_${site}_${p}"

            ensure_resource('cfnetwork::describe_service', $s, {
                server => "tcp/${p}",
            })
            ensure_resource('cfnetwork::client_port', "any:${s}", {
                user => $user,
            })
        }
    }
}
