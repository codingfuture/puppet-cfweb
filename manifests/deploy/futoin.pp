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

    String[1] $tool,
    String[1] $url,
    Optional[String[1]] $pool = undef,
    Optional[String[1]] $match = undef,
    Array[String[1]] $deploy_set = [],
    Hash[String[1], Hash] $fw_ports = {},
    Optional[String[1]] $custom_script = undef,
) {
    include cfweb::appcommon::cid

    $service_name = "app-${site}-futoin"
    $cid = '/usr/local/bin/cid'
    $user = $run_user

    #--------------


    Package['futoin-cid']
    -> file { "${site_dir}/.futoin-deploy.lock":
        ensure  => present,
        replace => no,
        content => '',
        owner   => $user,
        group   => $user,
        mode    => '0700',
    }
    -> file { "${site_dir}/.futoin.json":
        ensure  => present,
        replace => no,
        content => '{"env":{}}',
        owner   => $user,
        group   => $user,
        mode    => '0700',
    }
    -> file { "${site_dir}/persistent":
        ensure => link,
        target => $persistent_dir,
    }
    -> anchor { "futoin-deploy-${site}": }

    #--------------
    Anchor["futoin-deploy-${site}"]
    -> Cfweb_App[$service_name]

    #--------------
    cfweb::internal::deployerfw { $user:
        fw_ports => $fw_ports,
    }

    #--------------
    $deploy_type = $type ? {
        'rms' => "${type} ${pool}",
        default => $type
    }

    file { "${cfweb::nginx::bin_dir}/deploy-${site}":
        mode    => '0700',
        content => epp('cfweb/futoin_manual_deploy.epp', {
            site_dir    => $site_dir,
            user        => $user,
            deploy_type => $deploy_type,
            match       => $match,
        }),
    }

    file { "${cfweb::nginx::bin_dir}/redeploy-mark-${site}":
        mode    => '0700',
        content => epp('cfweb/futoin_mark_redeploy.epp', {
            site_dir => $site_dir,
        }),
    }
}
