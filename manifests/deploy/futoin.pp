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
    Optional[String[1]] $custom_script = undef,
) {
    include cfweb::appcommon::cid

    $service_name = "app-${site}-futoin"
    $cid = '/usr/local/bin/cid'

    #--------------


    Package['futoin-cid']
    -> file { "${site_dir}/.futoin-deploy.lock":
        ensure  => present,
        replace => no,
        content => '',
        owner   => $deploy_user,
        group   => $run_user,
        mode    => '0770',
    }
    -> file { "${cfweb::apps_home}/${deploy_user}/.futoin-global.lock":
        ensure  => present,
        replace => no,
        content => '',
        owner   => $deploy_user,
        group   => $run_user,
        mode    => '0770',
    }
    -> file { "${site_dir}/.runtime":
        ensure => directory,
        owner  => $deploy_user,
        group  => $run_user,
        mode   => '0770',
    }
    -> file { "${site_dir}/persistent":
        ensure => link,
        target => $persistent_dir,
    }
    -> exec { "futoin-setup-${site}":
        command => [
            "${cid} deploy setup",
            "--user=${run_user}",
            "--group=${run_user}",
        ].join(' '),
        cwd     => $site_dir,
        umask   => '0027',
        user    => $deploy_user,
    }
    -> anchor { "futoin-deploy-${site}": }

    #--------------
    $deploy_set.each |$cmd| {
        Exec["futoin-setup-${site}"]
        -> exec { "futoin-setup-${site}: ${cmd}":
            command => "${cid}  deploy set ${cmd}",
            cwd     => $site_dir,
            umask   => '0027',
            user    => $deploy_user,
        }
        -> Anchor["futoin-deploy-${site}"]
    }

    #--------------
    Anchor["futoin-deploy-${site}"]
    -> Cfweb_App[$service_name]

    #--------------
    if $custom_script {
        $custom_script_file = "${site_dir}/.custom_script.sh"

        file { $custom_script_file:
            owner   => $deploy_user,
            mode    => '0700',
            content => $custom_script,
        }
        -> exec { $custom_script_file:
            cwd   => $site_dir,
            umask => '0027',
            user  => $deploy_user,
        }
        -> Anchor["futoin-deploy-${site}"]
    }


    #--------------
    cfweb::internal::deployerfw { $deploy_user:
        fw_ports => $fw_ports,
    }
}
