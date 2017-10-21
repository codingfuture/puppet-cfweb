#
# Copyright 2017 (c) Andrey Galkin
#



type CfWeb::IMAP = Struct[{
    host => String[1],
    port => Integer[1, 65535],
    user => String[1],
    password => String[1],
    Optional[ssl] => Boolean,
}]
