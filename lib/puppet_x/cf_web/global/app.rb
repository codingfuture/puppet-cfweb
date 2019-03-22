#
# Copyright 2016-2019 (c) Andrey Galkin
#


module PuppetX::CfWeb::Global::App
    include PuppetX::CfWeb::Global
    
    def check_global(conf)
        slice_name = "#{PuppetX::CfWeb::SLICE_PREFIX}#{conf[:user]}"
        
        not self.cf_system().createSlice({
            :slice_name => slice_name,
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
            :dry_run => true,
        })
    end
    
    def create_global(conf)
        slice_name = "#{PuppetX::CfWeb::SLICE_PREFIX}#{conf[:user]}"
        
        self.cf_system().createSlice({
            :slice_name => slice_name,
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
        })
        return [slice_name]
    end
end
