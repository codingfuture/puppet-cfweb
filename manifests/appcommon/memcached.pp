
class cfweb::appcommon::memcached {
    package {'memcached':} ->
    service {'memcached':
        ensure => stopped,
        enable => false,
    }
}
