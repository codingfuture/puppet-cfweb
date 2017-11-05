#
# Copyright 2017 (c) Andrey Galkin
#


type CfWeb::BasicPassword = Variant[
    Struct[{
        Optional[plain] => String[1],
        Optional[crypt] => String[1],
        Optional[comment] => String,
    }],
    String[1]
]
