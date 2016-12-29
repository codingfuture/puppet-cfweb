
define cfweb::deploy(
    Enum[
        'svn',
        'git',
        'hg',
        'archiva',
        'artifactory',
        'nexus',
        'sftp',
    ] $type,
    String[1] $url,

    Boolean $find_latest = true,
    Integer[0] $depth = 0,
    Optional[String[1]] $match = undef,
    Enum[
        'symcode',
        'natural',
        'ctime',
        'mtime',
    ] $sort = 'natural',

    Boolean $is_tarball = true,

    String[1] $site,
    Array[String[1]] $apps,
) {
    fail('Not implemented yet')
}
