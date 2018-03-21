#
# Copyright 2017-2018 (c) Andrey Galkin
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
    Optional[Hash] $auto_deploy = undef,
    Optional[String[1]] $key_name = undef,
) {
    include cfweb::appcommon::cid

    $service_name = "app-${site}-futoin"
    $cid = '/usr/local/bin/cid'
    $user = $run_user
    $deployer_group = "deployer_${site}"

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
    if !empty($key_name) {
        ensure_resource( 'cfweb::internal::deploykey', $user, { key_name => $key_name } )

        Cfweb::Internal::Deploykey[$user]
        -> Anchor["futoin-deploy-${site}"]
    }
    elsif $url !~ /https?:/ {
        ensure_resource( 'cfweb::internal::clusterssh', $user )

        Cfweb::Internal::Clusterssh[$user]
        -> Anchor["futoin-deploy-${site}"]
    }

    #--------------
    Anchor["futoin-deploy-${site}"]
    -> Cfweb_App[$service_name]

    #--------------
    group { $deployer_group:
        ensure => present,
    }
    -> cfweb::internal::deployerfw { $deployer_group:
        fw_ports => $fw_ports,
    }
    ensure_resource('cfweb::nginx::group', $deployer_group)

    #--------------
    if $tool == 'svn' {
        file { "${site_dir}/.subversion":
            ensure => directory,
            owner  => $user,
            group  => $user,
            mode   => '0750',
        }
        -> file { "${site_dir}/.subversion/servers":
            owner   => $user,
            group   => $user,
            mode    => '0640',
            content => @("EOT"/$)
            [global]
            ssl-trust-default-ca = yes
            ssl-authority-files = /etc/ssl/certs/ca-certificates.crt
            |EOT
        }
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
            group       => $deployer_group,
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

    #---
    if $auto_deploy {
        create_resources(
            'cron',
            {
                "CFWEB AutoDeploy: ${title}" => {
                    command => "${cfweb::nginx::bin_dir}/deploy-${site}",
                }
            },
            $auto_deploy
        )
    }
}
