#
# Copyright 2017-2018 (c) Andrey Galkin
#


define cfweb::deploy::futoin(
    CfWeb::AppCommonParams $common,

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
    include cfweb::internal::deployuser

    $site = $common['site']
    $site_dir = $common['site_dir']
    $user = $common['user']
    $apps = $common['apps']
    $persistent_dir = $common['persistent_dir']

    $deployer_group = regsubst($user, /^app_/, 'deployer_')

    if size($apps) != 1 {
        $app_name = $common['app_name']
        $service_name = "app-${site}-${app_name}"
        $deploy_dir = "${site_dir}/${app_name}"
        $app_persistent_dir = "${persistent_dir}/${app_name}"
    } else {
        # NOTE: support site-level $deploy
        $service_name = "app-${site}-${apps[0]}"
        $deploy_dir = $site_dir
        $app_persistent_dir = $persistent_dir
    }

    #--------------

    Package['futoin-cid']
    -> file { "${deploy_dir}/.futoin-deploy.lock":
        ensure  => present,
        replace => no,
        content => '',
        owner   => $user,
        group   => $user,
        mode    => '0700',
    }
    -> file { "${deploy_dir}/.futoin.json":
        ensure  => present,
        replace => no,
        content => '{"env":{}}',
        owner   => $user,
        group   => $user,
        mode    => '0700',
    }
    -> file { "${deploy_dir}/persistent":
        ensure => link,
        target => $app_persistent_dir,
    }
    -> anchor { "futoin-deploy-${title}": }

    #--------------
    if !empty($key_name) {
        ensure_resource( 'cfweb::internal::deploykey', $user, { key_name => $key_name } )

        Cfweb::Internal::Deploykey[$user]
        -> Anchor["futoin-deploy-${title}"]
    }
    elsif $url !~ /https?:/ {
        ensure_resource( 'cfweb::internal::clusterssh', $user )

        Cfweb::Internal::Clusterssh[$user]
        -> Anchor["futoin-deploy-${title}"]
    }

    #--------------
    Anchor["futoin-deploy-${title}"]
    -> Cfweb_App[$service_name]

    #--------------
    ensure_resource('group', $deployer_group, {
        ensure => present,
    })
    ensure_resource('cfweb::nginx::group', $deployer_group)

    Group[$deployer_group]
    -> cfweb::internal::deployerfw { "futoin:${title}":
        fw_ports     => $fw_ports,
        deploy_group => $deployer_group,
    }

    #--------------
    if $tool == 'svn' {
        $home_dir = getparam(User[$user], 'home')

        ensure_resources(
            'file',
            {
                "${home_dir}/.subversion" => {
                    ensure => directory,
                    owner  => $user,
                    group  => $user,
                    mode   => '0750',
                },
                "${home_dir}/.subversion/servers" => {
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
        )
    }

    #--------------
    $deploy_type = $type ? {
        'rms' => "${type} ${pool}",
        default => $type
    }

    file { "${cfweb::nginx::bin_dir}/deploy-${title}":
        mode    => '0700',
        content => epp('cfweb/futoin_manual_deploy.epp', {
            deploy_dir  => $deploy_dir,
            user        => $user,
            group       => $deployer_group,
            deploy_type => $deploy_type,
            match       => $match,
        }),
    }

    file { "${cfweb::nginx::bin_dir}/redeploy-mark-${title}":
        mode    => '0700',
        content => epp('cfweb/futoin_mark_redeploy.epp', {
            deploy_dir => $deploy_dir,
        }),
    }

    #---
    if $auto_deploy {
        create_resources(
            'cron',
            {
                "CFWEB AutoDeploy: ${title}" => {
                    command => "${cfweb::nginx::bin_dir}/deploy-${title}",
                }
            },
            $auto_deploy
        )
    }
}
