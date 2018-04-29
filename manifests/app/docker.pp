#
# Copyright 2016-2018 (c) Andrey Galkin
#


define cfweb::app::docker (
    CfWeb::AppCommonParams $common,

    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Cfsystem::CpuWeight $cpu_weight = 100,
    Cfsystem::IoWeight $io_weight = 100,
) {
    fail('Not implemented yet')
}
