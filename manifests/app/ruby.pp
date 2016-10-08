
define cfweb::app::ruby (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,
    String[1] $template_global = 'cfweb/upstream_ruby',
    String[1] $template = 'cfweb/app_ruby',
    
    Integer[1] $memory_weight = 100,
    Optional[Integer[1]] $memory_max = undef,
    Integer[1,25600] $cpu_weight = 100,
    Integer[1,200] $io_weight = 100,    
    
) {
    fail('Not implemented yet')
}
