# cfweb

## Description

Complex management of security enforced web cluster in Continuous Deployment mode.

**This module is still in development!**

Provided for alpha-testing purposes and as reference continuous deployment integration of
[FutoIn CID](https://github.com/futoin/cid-tool).


### Terminology & Concept

Cluster is used to name related nodes. There can be only one cluster per system (for now).
As with [cfdb](https://github.com/codingfuture/puppet-cfdb) there is a primary node which
does all configuration.

Secondary nodes can only scale applications defined in primary node.

All key generation is done on primary node and securely copied to secondary nodes through
SSH using dedicated user account (`cfwebpki` by default).

By default self-signed certificates are generated on demand. It's possible to provide
external certificates. Automatic certificate creation (e.g. Let's Encrypt) is not completely
supported yet.


## Technical Support

* [Example configuration](https://github.com/codingfuture/puppet-test)
* Free & Commercial support: [support@codingfuture.net](mailto:support@codingfuture.net)

## Setup

Please use [librarian-puppet](https://rubygems.org/gems/librarian-puppet/) or
[cfpuppetserver module](https://forge.puppetlabs.com/codingfuture/cfpuppetserver) to deal with dependencies.

There is a known r10k issue [RK-3](https://tickets.puppetlabs.com/browse/RK-3) which prevents
automatic dependencies of dependencies installation.
