
module PuppetX::CfWeb
    class ProviderBase < PuppetX::CfSystem::ProviderBase
        def self.mixin_dbtypes(prov_type)
            @version_files = [__FILE__]
            @version_files << "#{BASE_DIR}/../puppet/provider/cfweb_#{prov_type}/cfweb.rb"
            
            CFWEB_TYPES.each do |t|
                self.extend(PuppetX::CfWeb.const_get(t.capitalize).const_get(prov_type.capitalize))
                @version_files << "#{BASE_DIR}/cf_web/#{t}/#{prov_type.downcase}.rb"
            end
        end
        
        def self.get_generator_version
            cf_system().makeVersion(@version_files)
        end
    end
end