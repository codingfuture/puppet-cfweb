#
# Copyright 2017-2018 (c) Andrey Galkin
#


type CfWeb::SMTP = Struct[{
    Optional[host] => String[1],
    Optional[port] => Integer[1, 65535],
    Optional[start_tls] => Boolean,
    Optional[auth_mode] => Enum['plain', 'login', 'cram_md5'],
    Optional[user] => String[1],
    Optional[password] => String[1],
    Optional[from] => String[1],
    Optional[reply_to] => String[1],
}]
