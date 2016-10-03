
define cfweb::app::jvm (
    String $site,
    String $user,
    String $site_dir,
    String $conf_prefix,
    Array[String] $dbaccess,
    String $template = 'cfweb/app_jvm',
    
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,    
) {
    fail('Not implemented yet')
}
