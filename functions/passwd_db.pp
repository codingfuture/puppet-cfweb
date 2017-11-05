#
# Copyright 2017 (c) Andrey Galkin
#


function cfweb::passwd_db(String[1] $realm) >> String {
    $users = $cfweb::global::users[$realm]
    $algo = 'sha-512'
    $salt = $realm.regsubst('[^a-zA-Z0-9./]', '', 'G')

    if !$users {
        fail("Missing realm config: \$cfweb::global::users[${realm}]")
    }

    $lines = (
        ["# ${realm}"] +
        ($users.map |$user, $v| {
            if $v =~ String[1] {
                $end = pw_hash($v, $algo, $salt)
            } else {
                if $v['crypt'] =~ String[1] {
                    $p = $v['crypt']
                } elsif $v['plain'] =~ String[1] {
                    $p = pw_hash($v['plain'], $algo, $salt)
                } else {
                    fail("Either set 'crypt' or 'plain' for ${user}@${realm}")
                }

                $end = "${p}:${v['comment']}"
            }

            "${user}:${end}"
        }) +
        ['# end']
    )

    $lines.join("\n")
}
