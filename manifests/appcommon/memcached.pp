#
# Copyright 2016-2017 (c) Andrey Galkin
#


class cfweb::appcommon::memcached {
    package {'memcached':}
    -> service {'memcached':
        ensure => stopped,
        enable => false,
    }
}
