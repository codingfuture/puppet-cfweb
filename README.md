# cfweb

## Description

Complex management of security enforced web cluster in Continuous Deployment mode.

This module is also a reference implementation of [FutoIn CID](https://github.com/futoin/cid-tool) support.

* Primary features
    * Cluster focused
    * Full systemd integration without extra supervisors
    * Broad set of technologies:
        * **Node.js** multi-version via global NVM
        * **PHP (FPM)** multi-version via Sury
        * **Python (uWSGI)** - only system py2 & py3 for now
        * **Ruby (Puma)** multi-version via Brightbox
        * any custom on top of **FutoIn CID** technology
    * Advanced limits framework
        * Virtual-host aware
        * Static/Dynamic/API aware
        * Custom limits support
        * Stress host support (exempt from limits)
    * TLS:
        * A+ configuration for TLS
        * Proper support of TLS tickets with configurable rotation period
        * Per cluster generated DH params
        * Automatic certificate provisioning
        * Automatic certificate signing: ACME (Let's Encrypt)
        * Dual RSA+ECDSA setup
    * Continuous Delivery:
        * Automatic deployment via FutoIn CID
        * Tunable resource distribution based on available resources
        * Secure auto-deployment user for external calls via SSH
        * Zero-downtime rolling reload
        * Automatic DB configuration based on [cfdb](https://codingfuture.net/docs/cfdb)
        * Deploy the latest from VCS tag and branch (CID feature)
        * Deploy the latest from RMS packages (CID feature)
    * Auto-configuration of nginx
    * Access control
        * Per site HTTP Basic Auth configuration
        * IP-based client whitelisting
        * X.509 PKI verification
    * Hardened security:
        * Each app runs under own user
        * cgroup resource isolation
        * Read-only permission with persistent read-write locations (CID feature)
        * Deployment process has own network access (for VCS, RMS, npm, GitHub, etc.)
        * No outgoing network access for apps by default
        * Apps cannot access each other, nginx service has aux group of each app
        * HTTP_PROXY and other known attack mitigation
        * Automatic systemd-based restart
    * Misc:
        * HTTP/2
        * Multiple IP/interface aware
        * External balancer with Proxy Protocol support
        * Automatic redirection HTTP -> HTTPS (configurable)
        * Automatic redirection of aliases to main vhost (SEO friendly)
        * Disallow robot indexing via /robots.txt - avoid showing private sites in search engines
        * Support for very large content site, not suitable for FutoIn CID deployment approach
        * Firewall configuration through [cfnetwork](https://codingfuture.net/docs/cfnetwork)


### Terminology & Concept

Cluster is used to name related nodes. There can be only one cluster per system (for now).
As with [cfdb](https://codingfuture.net/docs/cfdb) there is a primary node which
does all configuration.

Secondary nodes can only scale applications defined in primary node. Secondary nodes need not
to be symmetric or handle the all application defined in primary node.

All key generation is done on primary node and securely copied to secondary nodes through
SSH using dedicated user account (`cfwebpki` by default).

By default self-signed certificates are generated on demand. It's possible to provide
external certificates. Automatic certificate creation (e.g. Let's Encrypt) is also supported.

Site types:
* "Standalone" - internet facing site
* "Backend" - assumes to run behind balancer implementing Proxy Protocol
* "Frontend" - actual load balancer with TLS termination

Limit types with default values:
* peraddr = 128 - total connections per client address
* peraddrpersrv = 32 - connections per client address per one virtual host
* static = 100r/s, burst=300 - requests per second for static content per client address
* dynamic = 10r/s, burst=20 - requests per second to dynamic pages per client address
* api = 64r/s, burst=64 - requests per second to protect API endpoints per client address
* unlikely = 1r/s, burst=3 - request per second to places which should not be reached by clients per client address

Continuous Delivery strategies:
* ssh trigger - special user which can only trigger secure deploy/re-deployment of all or specific app
* cron - periodically try to deploy a new version, if available
    * good for fallback/backup, if ssh trigger fails by any reason
* custom - only need to trigger pre-installed scripts

App control helpers:
* Located under /www/bin
* Deploy:
    * `deploy` - run "cid deploy" for all configured sites
    * `deploy {site}` and `deploy-{site}` - run "cid deploy" only for specific sites
    * `redeploy-mark-{site}` - mark site for "cid deploy --redeploy" on next deployment
* Graceful reload:
    * `reload` - reload all apps
    * `reload-{site}` - reload specific site apps
* Rolling restart:
    * `restart` - restart all apps
    * `restart-{site}` - restart specific site apps
* Start apps:
    * `start` - start all apps
    * `start-{site}` - start specific site apps
    * `start-{site}-{app}` - start specific app of specific site
* Stop apps:
    * `stop` - stop all apps
    * `stop-{site}` - stop specific site apps
    * `stop-{site}-{app}` - stop specific app of specific site

## Technical Support

* [Example configuration](https://github.com/codingfuture/puppet-test)
* Free & Commercial support: [support@codingfuture.net](mailto:support@codingfuture.net)

## Setup

Up to date installation instructions are available in Puppet Forge: https://forge.puppet.com/codingfuture/cfweb

Please use [librarian-puppet](https://rubygems.org/gems/librarian-puppet/) or
[cfpuppetserver module](https://codingfuture.net/docs/cfpuppetserver) to deal with dependencies.

There is a known r10k issue [RK-3](https://tickets.puppetlabs.com/browse/RK-3) which prevents
automatic dependencies of dependencies installation.

## Example

Please check real-world complex Redmine issue tracker setup in [cfwebapp](https://codingfuture.net/docs/cfwebapp) recipe.

## API

The API is quite large. So, only essential parts are listed.

### class `cfweb`

The main class only points to parts of `cfweb::global` configuration to use for particular node.

* `$cluster` - infrastructure-wide cluster name
* `$is_secondary` - must be true for all additional nodes
* `$standalone` - list of "standalone" site names to deploy
* `$backends` - list of "backend" site names to deploy
* `$frontends` - list of "frontend" site names to deploy (not yet supported)
* `$cluster_hint` - CIDR address of additional nodes to open firewall in advance (simplify deployment)
* `$deployuser = deployweb` - user accessible via SSH with only permission to trigger re-deployment of applications
* `$deployuser_auth_keys` - list of SSH keys to for deploy user


### class `cfweb::global`

Does not do anything. The reason is to define cluster-wide resources which can used in nodes.
Designed this way to avoid discrepancies between nodes. Primary configuration happens here.

* `$sites` - hash of named parameters for `cfweb::site` resources
* `$keys` - hash of named parameters for `cfweb::pki::key` resources
* `$certs` - hash of named parameters for `cfweb::pki::cert` resources to be used in `$cfweb::site::shared_cert`
* `$users` - hash of named realms to user definition list.
    * realm name
        * user => plain password
        * user => 
            - plain => plain password
            - crypt => already hashed password (instead of the plain one)
            - comment => optional comment
* `$hosts` -  has of named lists of hosts for IP-based access
* `$deploy_keys = {}` - name to `{ private => ..., public => ...}` keys to be used solely for read-only
    access of SSH sources for deployment.
* `$client_pki = {}` - named definitions of client PKI
    * name to to hash:
        - `ca` - CA PEM format as is
        - or `ca_source` - suitable for puppet `File::source` parameter
        - `crl` - CRL PEM format as is
        - or `crl_source` - suitable for puppet `File::source` parameter
        - `depth = 1` - client verification chain max depth

### class `cfweb::nginx`

Main setup and configuration of nginx web server.

* Resource distribution based on `cfsystem` framework
    * `$memory_weight = 100`
    * `$memory_max = 256`
    * `$cpu_weight = 100`
    * `$io_weight = 100`
* `$settings_tune = {}` - tree for fine tune of nginx.conf
    * `cfweb = {}` - tune of `cfweb` itself
        - 'extra_files = 20000' - extra file descriptors, affects open file cache
        - 'mem_per_conn = 128' - expected memory requirement per connection in KiB
        - 'ssl_sess_factor = 3' - multiplier of max conn for ssl cache size
        - 'use_syslog' - auto-detected based on cflogsink::client
* `$trusted_proxy = []` - list of trusted reverse-proxies
* `$default_certs = {}` - cert names to use for the default catch all vhosts
* `$backlog = 4096` - tune backlog
* `$limits = {} or "unlimited"` - override default limit settings and/or add custom
    - `type` - 'conn' or 'req'
    - `var` - nginx variable to use
    - `count` - for 'conn' type
    - `entry_size` - suggest size of `var` values
    - `rate` - rate for 'req' type
    - `burst` - burst for 'req' type
    - `nodelay` - control no-delay rejection behavior
    - `disabled` - disable particular limit
* `$stress_hosts` - list of hosts for which limits are ignored
* `$bleeding_edge_security = false` - add more strict TLS security based on MDN definitions
* `$repo = 'http://nginx.org/packages/'` - repo to get nginx packages from
* `$mainline = false` - uses nginx mainline releases, if true


### class `cfweb::pki`

Setups infrastructure for PKI management with cluster-wide sync.
All keys and CSRs are generated on primary node and then distributed to slaves.

*Note: by default all keys and certs are located under /home/cfwebpki/shared/* 

* Default x509 parameters for CSR generation and ACME sources
    * `$x509_c`
    * `$x509_st`
    * `$x509_l`
    * `$x509_o`
    * `$x509_ou`
    * `$x509_email`
* `$dhparam_bits = 2048` - default bits for DH params
* `$rsa_key_name = 'multi'` - default key name to use for RSA CSRs and certs
* `Cfsystem::Rsabits $rsa_bits = 2048` - default size of RSA keys
* `$ecc_key_name = 'multiec'` - default key name to use for ECC CSRs and certs
* `$ecc_curve = 'prime256v1'` - default curve for ecdsa keys
* `$cert_hash = 'sha256'` - cert hash to use
* Inter-node SSH rsync, see `cfsystem::clusterssh`:
    * `$ssh_user = 'cfwebpki'`
    * `Cfsystem::Keytype $ssh_key_type = 'ed25519'`
    * `Cfsystem::Rsabits $ssh_key_bits = 2048`
* TLS ticket rotation:
    * `$tls_ticket_key_count = 3` - how many ticket keys to keep
    * `$tls_ticket_key_age = 1440` - max age before rotation
    * `$tls_ticket_cron = every three hours` - cron config to try regeneration 
* `$cert_source = undef` - default source for certs
    * `acme` - use Let's Encrypt

### type `cfweb::pki::key`

Defines TLS private key parameters. The key is not regenerated unless key file is manually deleted.

* `$key_name = $title`
* Overrides of `cfweb::pki` defaults:
    * `$key_type`
    * `$key_bits`
    * `$key_curve

### type `cfweb::pki::cert`

Defines x509 certificate and CSR for it. CSR is not regenerated unless the file is manually deleted.

* `$cert_name = $title`
* `$alt_names = []` - alternative DNS names (CN is auto-added as #1)
* `$cert_source = undef` - can "acme" for Let's Encrypt or "{module}/{file}" cert bundle
* `$x509_cn = $cert_name`
* Overrides of `cfweb::pki` defaults:
    * `$key_name = undef`
    * `$x509_c`
    * `$x509_st`
    * `$x509_l`
    * `$x509_o`
    * `$x509_ou`
    * `$x509_email`
    * `$cert_hash = undef`

### type `cfweb::site`

Main resource type to define virtualhost with related apps.

* `$server_name = $title` - primary hostname
* `$alt_names = []` - alternative names
* `$redirect_alt_names = true` - force redirect to primary hostname
* `$ifaces = ['main']` - interface to bind to
* `$plain_ports = [80]` - list of plain HTTP listen ports
* `$tls_ports = [443]` - list of HTTPS listen ports
* `$redirect_plain = true` - redirect plain HTTP requests to HTTPS
* `$is_backend = false` - for internal use only based on `$cfweb::backends`
* `$auto_cert = {}` - `cfweb::pki::cert` overrides for default CSR
* `$shared_cert = undef` - name shared cert to use instead of auto-generated
* `$dbaccess` - list of `cfdb::access` connections
* `$apps = { 'static' => {} }` - applications to setup
* `$custom_conf = undef` - additional snippet to put into nginx `server` section
* Overall weights in `cfsystem` resource distribution framework:
    * `Cfsystem::CpuWeight $cpu_weight = 100`
    * `Cfsystem::IoWeight $io_weight = 100`
* `CfWeb::Limits $limits = {}` - overrides and/or custom connection/requests limits
* `CfWeb::DotEnv $dotenv = {}` - custom `cfsystem::dotenv` resources
* `$force_user = undef` - force app user name to use instead
* `$robots_noindex = false` - add default /robots.txt which forbids indexing
* `$require_realm = undef` - require basic auth of specified realm as defined in `$cfweb::global::users`
* `$require_hosts = undef` - require clients only from whitelisted hosts
* `$require_x509 = undef` - string of `cfweb::global::clientpki` name or a hash of:
    * `clientpki` - `cfweb::global::clientpki` name
    * `verify = on` - override verification mode
* `$hsts = 'max-age=15768000; includeSubDomains; preload'` - HSTS, optional
    * enabled only at TLS termination
* `$xfo = 'sameorigin' - X-Frame-Options, optional
    * enabled only at TLS termination
* `$deploy = undef` - optional deployment strategy parameters

### Deploy strategy

#### FutoIn

Deployment process is based on FutoIn CID. The source code may have no support for it, but
it's still possible to do all configuration in target deployment through override mechanism.

* `$strategy = 'futoin'`:
* `$type` - 'rms', 'vcstag' or 'vcsref' 
* '$tool' - deploy tool: svn, git, hg, scp, archiva, artifactory, nexus, etc.
* '$url' - tool URL
* `$pool = undef` - RMS pool
* `$match = undef` - tag or package glob match
* `$deploy_set = []` - custom "cid deploy set {X}" commands
* `$fw_ports = {}` - additional firewall ports to open for deployment process
* `$custom_script = undef` - custom script to run before actual "cid deploy"
* `$auto_deploy = undef` - cron config for periodic re-deploy
* `$key_name = undef` - SSH key name to use for read-only access of deployment sources

### app parameters

#### `static`

Can be mixed with others, unless stated otherwise. Only suitable for very special cases
where FutoIn CID approach does not fit.

Examples:
* Network mounts (NFS, Samba, GlusterFS, etc.)
* Very large VCS repositories

Params:
* `$images = true` - regex location for images (binary content)
* `$assets = true` - regex location for text content
* `$asset_gz = true` - enable gzip for text content
* `$asset_static_gz = true` - try serving of static .gz content
* `$forbid_dotpath = true` - forbid access to files starting with dot
* `$default_app = undef` - pass control to other app, if file is not found
* `$autoindex = false` - enable auto-index
* `$index = ['index.html','index.htm']` - index files to try for directories
* `$web_root = '/'` - location of public root relative to {deploy dir}/current/
* `$serve_root = true` - serve public root not matching regex locations

#### `futoin`

FutoIn CID inner resource distribution comes into play after `cfsystem` distributes
resources of system level.

FutoIn CID creates has complex decisions for resource distribution and app instances
generation to utilize all available resources and support rolling restart. Please
check its README.

* App's resource limits in scope of `cfsystem` resource distribution framework. 
    * `Integer[1] $memory_weight = 100`
    * `Integer[64] $memory_min = 64`
    * `Optional[Integer[1]] $memory_max = undef`
    * `Cfsystem::CpuWeight $cpu_weight = 100`
    * `Cfsystem::IoWeight $io_weight = 100`
* `$fw_ports = {}` - hash of fw service => params for `cfnetwork::client_ports`
* `$tune = {}` - fine tune behavior
    * `upstreamKAPercent = 25` - percent of upstream max connection to keep alive
    * `upstreamQueue = undef` - NGINX Plus upstream queue
    * `upstreamFailTimeout = 0` - fail_timeout for upstream
    * `upstreamZoneSize = 64k' - zone upstreams for consistent hashing
* `$deploy` - see FutoIn deploy strategy paramaters

#### `proxy`

Must be exclusive app. Useful for simple reverse proxy of low capability HTTP host with
advanced security features of cfweb module.

Clients can use TLS with HTTP/2 and require all supported authentication methods. Upstream
is assumed to be HTTP/1.1 with keepalive support. WebSockets upgrade is also supported.

Example: custom running daemon access and/or network equipment web panel proxy.

Params:
* `$upstream` - hash or array of hashes:
    - `$port` - integer(TCP) or string (UNIX socket)
    - `$host` - optional IP or hostname
    - `$max_conns` - optional, see nginx.conf    
    - `$max_fails` - optional, see nginx.conf    
    - `$fail_timeout` - optional, see nginx.conf    
    - `$backup` - optional, see nginx.conf    
    - `$weight` - optional, see nginx.conf
* `$keepalive = 8` - see nginx.conf
* `$path = '/'` - site path
* `$uppath = ''` - path in upstream (see nginx behavior)

#### `multiproxy`

Easy shortcut to define many `proxy` apps.

* `$paths` - map of `$path` to other `proxy` parameter pairs

#### `docker`

Not implemented yet, but supported in FutoIn CID


