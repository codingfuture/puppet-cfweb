
define cfweb::app::static (
    String[1] $site,
    String[1] $user,
    String[1] $site_dir,
    String[1] $conf_prefix,
    String[1] $type,
    Array[String[1]] $dbaccess_names,
    String[1] $template = 'cfweb/app_static',
    
    Boolean $serve_root = true,
    
    Variant[Boolean, String] $images = true,
    Variant[Boolean, String] $assets = true,
    
    Boolean $asset_gz = true,
    Boolean $asset_static_gz = true,
    Boolean $forbid_dotpath = true,
    
    Optional[String] $default_app = undef,
    Boolean $autoindex = false,
    Variant[String, Array[String]] $index = [
        'index.html',
        'index.htm',
    ],
) {
    if $default_app {
        $default_app_act = $default_app
    } else {
        $other_apps = (keys(getparam(Cfweb::Site[$site], 'apps')) - ['static'])
        
        if size($other_apps) > 1 {
            fail("Failed to auto-detect default app for ${site}. Please define it.")
        }
        
        $default_app_act = $other_apps[0]
    }
    
    $web_root = getparam(Cfweb::Site[$site], 'web_root')
    
    file { "${conf_prefix}.global.static":
        mode    => '0640',
        content => '',
    }
    file { "${conf_prefix}.server.static":
        mode    => '0640',
        content => epp($template, {
            site            => $site,
            document_root   => "${site_dir}/current${web_root}",
            serve_root      => $serve_root,
            images          => $images,
            assets          => $assets,
            asset_gz        => $asset_gz,
            asset_static_gz => $asset_static_gz,
            forbid_dotpath  => $forbid_dotpath,
            default_app     => $default_app_act,
            autoindex       => $autoindex,
            index           => any2array($index),
        }),
    }
    
}
