#
# Copyright 2016-2017 (c) Andrey Galkin
#


define cfweb::deploy(
    Enum[
        'svn',
        'git',
        'hg',
        'archiva',
        'artifactory',
        'nexus',
        'sftp'
    ] $type,
    String[1] $url,

    Boolean $find_latest = true,
    Integer[0] $depth = 0,
    Optional[String[1]] $match = undef,
    Enum[
        'symcode',
        'natural',
        'ctime',
        'mtime'
    ] $sort = 'natural',

    Boolean $is_tarball = true,

    # internal options
    String[1] $site = undef,
    String[1] $user = undef,
    String[1] $site_dir = undef,
    String[1] $persistent_dir = undef,
    Array[String[1]] $apps = undef,
) {
    assert_private()
    fail('Not implemented yet')
}
