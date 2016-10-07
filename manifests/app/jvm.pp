
define cfweb::app::jvm (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    Array[String[1]] $dbaccess,
    String[1] $template_global = 'cfweb/upstream_jvm',
    String[1] $template = 'cfweb/app_jvm',
    
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,    
) {
    fail('Not implemented yet')
}
