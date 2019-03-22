#
# Copyright 2017-2019 (c) Andrey Galkin
#


class cfweb::internal::cidrepos {

    include cfsystem
    include cfweb::global

    #====
    if $cfweb::global::ruby {
        $ruby_release = $::facts['os']['name'] ? {
            'Debian' => $::cfsystem::debian::release ? {
                'jessie' => 'trusty',
                default => 'xenial',
            },
            'Ubuntu' => $::cfsystem::ubuntu::release,
        }

        apt::key { 'brightbox-ruby':
            id      => '80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6',
            content => file('cfweb/brightbox_rubyng_signing.key'),
        }

        apt::source { 'brightbox-ruby':
            location      =>'http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu',
            release       => $ruby_release,
            repos         => 'main',
            pin           => $cfsystem::apt_pin,
            notify_update => false,
            notify        => Exec['cf-apt-update'],
            require       => Apt::Key['brightbox-ruby'],
        }
    }

    #====
    if $cfweb::global::php {
        case $::facts['os']['name'] {
            'Debian' : {
                apt::key { 'sury-php':
                    id      => 'DF3D585DB8F0EB658690A554AC0E47584A7A714D',
                    content => file('cfweb/sury_signing.key'),
                }

                apt::source { 'sury-php':
                    location      =>'http://packages.sury.org/php',
                    release       => $::cfsystem::debian::release,
                    repos         => 'main',
                    pin           => $cfsystem::apt_pin,
                    notify_update => false,
                    notify        => Exec['cf-apt-update'],
                    require       => Apt::Key['sury-php'],
                }
            }
            'Ubuntu' : {
                apt::key { 'sury-php':
                    id      => '14AA40EC0831756756D7F66C4F4EA0AAE5267A6C',
                    content => file('cfweb/sury_ppa_signing.key'),
                }

                apt::source { 'sury-php':
                    location      =>'http://ppa.launchpad.net/ondrej/php/ubuntu',
                    release       => $::cfsystem::ubuntu::release,
                    repos         => 'main',
                    pin           => $cfsystem::apt_pin,
                    notify_update => false,
                    notify        => Exec['cf-apt-update'],
                    require       => Apt::Key['sury-php'],
                }
            }
            default : { fail('Unsupported OS') }
        }
    }
    #====
}
