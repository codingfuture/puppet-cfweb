#
# Copyright 2016-2017 (c) Andrey Galkin
#


module PuppetX::CfWeb::Global::App
    include PuppetX::CfWeb::Global
    
    def check_global(conf)
        not self.cf_system().createSlice({
            :slice_name => conf[:user],
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
            :dry_run => true,
        })
    end
    
    def create_global(conf)
        self.cf_system().createSlice({
            :slice_name => conf[:user],
            :cpu_weight => conf[:cpu_weight],
            :io_weight => conf[:io_weight],
        })
        return []
    end
end
