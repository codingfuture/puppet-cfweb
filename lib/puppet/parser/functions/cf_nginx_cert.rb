#
# Copyright 2016-2017 (c) Andrey Galkin
#


module Puppet::Parser::Functions
    newfunction(:cf_nginx_cert,  :type => :rvalue, :arity => 2) do |args|
        require 'openssl'
        
        raw_certs = args[0]
        common_name = args[1]
        
        begin_cert = '-----BEGIN CERTIFICATE-----'
        end_cert = '-----END CERTIFICATE-----'
        certs = []
        raw_certs.split(end_cert).each do |v|
            v = v.strip()
            
            next if v.empty?
            
            if not v.start_with?(begin_cert)
                fail("Not a valid cert for #{common_name}: #{v}")
            end
            
            certs << OpenSSL::X509::Certificate.new("#{v}\n#{end_cert}")
        end
        
        # find root
        #---
        root_ca = certs.find do |v|
            v.issuer == v.subject
        end
        
        if root_ca.nil?
            fail("Failed to find Root CA for #{common_name}")
        end
        
        chain = []
        chain << root_ca.to_pem
        
        # build chain
        #---
        curr = root_ca
        found_subjects = []
        
        while true
            subj = curr.subject.to_a.find { |v| v[0] == 'CN' }
            subj = subj[1]
            found_subjects << subj
            
            break if subj == common_name
            
            curr = certs.find do |v|
                v.issuer == curr.subject and v.subject != curr.subject
            end
            
            if curr.nil?
                fail("Failed to build full chain for #{common_name}: #{found_subjects.to_s}")
            end
            
            chain << curr.to_pem
        end
        
        #---
        # Based on docs:
        # chained: cert -> Intermediate CA
        # trusted: RootCA -> Intermediate CA
        {
            'chained' => chain.reverse[0, chain.size()-1], 
            'trusted' => chain[0, chain.size()-1], 
        }
    end
end
