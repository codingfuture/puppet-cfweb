# (next)
- CHANGED: /www/empty permission to 0755 for CID v0.8.29+ support
- CHANGED: revised TLS configuration to current recommendations
- CHANGED: to disable SSL session cache in clusters by default
- FIXED: proxy location not to limit max client body size
- FIXED: upstream hash to properly use hosts
- FIXED: edge case of static files location backed by app
- FIXED: minor issues in some docker configurations
- FIXED: a bug in limits configuration related stress host mapping
- NEW: backup_persistent option support for cfweb::site
- NEW: CID Erlang stack support
- NEW: --env-file for Docker support
- NEW: X-Frame-Options with sameorigin by default
- NEW: dual RSA+ECDSA certificate support

# 1.3.1 (2019-06-17)
- FIXED: minor warning on cfweb_sync_pki due to times issue
- FIXED: minor issues in deployment
- FIXED: scheme/protocol when behind trusted reverse-proxy
- CHANGED: to use ControlMaster SSH option for deployments

# 1.3.0 (2019-04-14)
- FIXED: appcommon::cid to include deps
- FIXED: failed initial acme challenge retry
- FIXED: new cert sync/reload issues on secondary nodes
- FIXED: to support "disabled" in limits configuration
- CHANGED: to proxy_pass acme challenge from secondary nodes
- CHANGED: aligned with CID to install Xenial Ruby repos for Debian
- CHANGED: to use 'keep-alive' instead of 'close' Connection header for proxy_pass
- CHANGED: to apply "static" limit on vhost basis
- CHANGED: got rid of historical cf-apt-update workaround
- NEW: /health.txt for default host
- NEW: backend auto-discovery support
- NEW: "unlimited" placeholder for site limits
- NEW: cfbackup integration for persistent directories
- NEW: experimental Docker support

# 1.2.0 (2018-12-09)
- CHANGED: updated for Ubuntu 18.04 Bionic support
- CHANGED: to use cfhttp service in firewall config
- FIXED: missing cflogsink dependency
- FIXED: to create "system users"
- FIXED: not to disallow cfwebpki through cron.deny
- NEW: possibility to disable nginx for non-web nodes

# 1.1.2 (2018-05-02)
- FIXED: cfweb::app::static to support arbitrary names
- NEW: nginx metrics support
- NEW: Copy-on-Write aware cgroup memory limits (overcommit)

# 1.1.1 (2018-04-29)
- FIXED: cfweb::app::futoin::fw_ports issue after recent refactoring

# 1.1.0 (2018-04-29)
- CHANGED: to use cfsystem::pip
- CHANGED: to use reuseport for nginx listen on privileged ports
- CHANGED: to allow zero memory distribution to static sites with futoin-cid
- CHANGED: to allow multiple apps of the same type per site
- CHANGED: HSTS not to include subdomains by default
- FIXED: missing module hiera.yaml
- FIXED: invalid configuration in some cases when only plain HTTP is used per host
- FIXED: bug when app group was not added to nginx user, if group is prefix of existing
- NEW: implemented native "proxy" and "multiproxy" app type support

# 1.0.1 (2018-04-12)
- FIXED: LetsEncrypt certificate rotation in cron

# 0.12.4 (2018-03-24)
- CHANGED: to create per-app clusterssh only if necessary for deployment
- FIXED: to allow 'local' bind iface for apps
- FIXED: removed "pip" from external setup whitelist
- NEW: deploy/futoin::key_name && globals::deploy_keys support
- NEW: X.509 PKI support for access control

# 0.12.3 (2018-03-19)
- CHANGED: to use cf_notify for warnings

# 0.12.2 (2018-03-15)
- CHANGED: to use cflogsink module for centralized logging, if configured
- CHANGED: ruby & php repos not to have priority over default packages (fixes old openssl problem)

# 0.12.1 (2018-03-10)
- FIXED: uWSGI & PHP-FPM to use proper syslog tag
- FIXED: not to cleanup PHP sessions via cron
- FIXED: acme.sh cron racing with cfweb_acme_cron
- NEW: cflogsink / syslog logging support
- NEW: cfweb::app:futoin::memory_min option

# 0.12.0 (2017-02-09)
- NEW: version bump of cf* series

# 0.11.6 (2017-12-15)
- FIXED: CfWeb::DBAccess definition

# 0.11.5 (2017-12-14)
- FIXED: quick workaround for flyway executable missing permissions

# 0.11.4 (2017-12-14)
- FIXED: to allow "http", "https" and "ssh" for per-site outgoing connections (used to work as aliases)

# 0.11.3 (2017-11-21)
- FIXED: not to put systemd app units into failed state due to ExecStop failures
- FIXED: to reload apps on manual deploy

# 0.11.2 (2017-11-19)
- FIXED: manual deploy to run under deployer group

# 0.11.1 (2017-11-07)
- FIXED: to properly use fine-tuned nginx config from futoin.json

# 0.11.0
Initial release for Alpha-testing
