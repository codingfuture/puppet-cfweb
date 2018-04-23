#
# Copyright 2018 (c) Andrey Galkin
#


type CfWeb::Upstream = Struct[{
    host         => Optional[String[1]],
    port         => Variant[String[1], Cfnetwork::Port],
    max_conns    => Optional[Integer[0]],
    max_fails    => Optional[Integer[0]],
    fail_timeout => Optional[Integer[0]],
    backup       => Optional[Boolean],
    weight       => Optional[Integer[0]],
}]
