#
# Copyright 2017-2019 (c) Andrey Galkin
#


type CfWeb::Limits = Hash[String[1], Struct[{
    type       => Enum['conn', 'req'],
    var        => String[1],
    count      => Optional[Integer[1]],
    entry_size => Optional[Integer[1]],
    rate       => Optional[String[1]],
    burst      => Optional[Integer[0]],
    nodelay    => Optional[Boolean],
    newname    => Optional[String[1]],
}]]
