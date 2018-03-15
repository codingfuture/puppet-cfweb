
# (next)
CHANGED: to use cflogsink module for centralized logging, if configured
CHANGED: ruby & php repos not to have priority over default packages (fixes old openssl problem)

# 0.12.1 (2018-03-10)
FIXED: uWSGI & PHP-FPM to use proper syslog tag
FIXED: not to cleanup PHP sessions via cron
FIXED: acme.sh cron racing with cfweb_acme_cron
NEW: cflogsink / syslog logging support
NEW: cfweb::app:futoin::memory_min option

# 0.12.0 (2017-02-09)
NEW: version bump of cf* series

# 0.11.6 (2017-12-15)
FIXED: CfWeb::DBAccess definition

# 0.11.5 (2017-12-14)
FIXED: quick workaround for flyway executable missing permissions

# 0.11.4 (2017-12-14)
FIXED: to allow "http", "https" and "ssh" for per-site outgoing connections (used to work as aliases)

# 0.11.3 (2017-11-21)
FIXED: not to put systemd app units into failed state due to ExecStop failures
FIXED: to reload apps on manual deploy

# 0.11.2 (2017-11-19)
FIXED: manual deploy to run under deployer group

# 0.11.1 (2017-11-07)
FIXED: to properly use fine-tuned nginx config from futoin.json

# 0.11.0
Initial release for Alpha-testing
