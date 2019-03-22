#
# Copyright 2018-2019 (c) Andrey Galkin
#


type CfWeb::ClientX509 = Variant[
    Struct[{
        clientpki => String[1],
        verify    => Optional[String[1]],
    }],
    String[1]
]
