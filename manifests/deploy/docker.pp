#
# Copyright 2019 (c) Andrey Galkin
#


define cfweb::deploy::docker (
    CfWeb::AppCommonParams $common,

    Cfnetwork::Port $target_port,

    Optional[CfWeb::DockerImage]
        $image = undef,
    Optional[String[1]]
        $dockerfile = undef,
    Optional[String[1]]
        $env_file = undef,
    Hash[String[1],String[1]]
        $binds = {},
    Array[String[1]]
        $hosts = [],
    Hash
        $tune = {},
    Optional[String[1]]
        $custom_script = undef,
    Array[String[1]]
        $config_files = [],
    String[1]
        $network = $title,
    Array[String[1]]
        $custom_args = [],
){
    include cfweb::appcommon::docker

    # ---
    $persistent_dir = $common['persistent_dir']
    $site_dir = $common['site_dir']
    $user = $common['user']

    file { "${site_dir}/persistent":
        ensure => link,
        target => $persistent_dir,
    }
    -> cfsystem::add_group($user, $cfweb::appcommon::docker::group)
    -> anchor { "docker-deploy-${title}": }

    # Ensuring an image
    # ---
    if !empty($image) and !empty($dockerfile) {
        fail("Please specify either 'image' or 'dockerfile' for ${title}")
    }

    if !empty($image) {
        create_resources('docker::image', {
            $title => $image + { ensure => latest }
        })
    } elsif !empty($dockerfile) {
        $docker_file_location = "${cfweb::appcommon::docker}/${title}"

        file { $docker_file_location:
            content => $dockerfile,
        }

        docker::image { $title:
            ensure      => present,
            docker_file => $docker_file_location,
            subscribe   => File[$docker_file_location],
        }
    }

    # Ensuring overlay network
    # ---
    ensure_resource('docker_network', $network, {
        ensure           => present,
        driver           => overlay,
        additional_flags => ['--attachable'],
    })
}
