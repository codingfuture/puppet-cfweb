#
# Copyright 2017 (c) Andrey Galkin
#


define cfweb::deploy::futoin(
    String[1] $site,
    String[1] $run_user,
    String[1] $deploy_user,
    String[1] $site_dir,
    String[1] $persistent_dir,
    Array[String[1]] $apps,

    Enum[
        'rms',
        'vcsref',
        'vcstag'
    ] $type,

    String[1] $url,
    Optional[String[1]] $pool = undef,
    Optional[String[1]] $match = undef,
    Array[String[1]] $deploy_set = [],
    Hash[String[1], Hash] $fw_ports = {},
) {
    require cfweb::appcommon::cid

    $service_name = "app-${site}-${type}"

    if $type == 'rms' {
        $url_arg = 'rmsRepo'
        $deploy_args = "rms '${pool}' 'pick_default(${match}, '')'"
    } else {
        $url_arg = 'vcsRepo'
        $deploy_args = "${type} 'pick_default(${match}, '')'"
    }

    exec { "futoin-setup-${site}":
        command => [
            'cid deploy setup',
            "--deployDir=${site_dir}",
            "--user=${run_user}",
            "--group=${run_user}",
            "--runtimeDir=/run/${service_name}",
        ].join(' '),
        umask   => '027',
        user    => $deploy_user,
    }
    -> exec { "futoin-deploy-${site}":
        command => [
            '/usr/local/bin/cid',
            "deploy ${deploy_args}",
            "--${url_arg}=${url}",
            "--deployDir=${site_dir}",
        ].join(' '),
        umask   => '027',
        user    => $deploy_user,
    }
    ~> Cfweb_App[$service_name]

    $deploy_set.each |$cmd| {
        Exec["futoin-setup-${site}"]
        -> exec { "futoin-setup-${site}: ${cmd}":
            command => "cid deploy set ${cmd} --deployDir=${site_dir}",
            umask   => '027',
            user    => $deploy_user,
        }
        -> Exec["futoin-deploy-${site}"]
    }

    # Allow package retrieval
    cfnetwork::client_port { "any:http:${deploy_user}":
        user => $deploy_user,
    }
    cfnetwork::client_port { "any:https:${deploy_user}":
        user => $deploy_user,
    }


    $fw_ports.each |$svc, $def| {
        create_services('cfnetwork::client_port', {
            "any:${svc}:${deploy_user}" => merge($def, {
                user => $deploy_user
            }),
        })
    }
}
