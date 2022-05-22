WAF Proxy
=========

[![Test and release](https://github.com/riotkit-org/waf-proxy/actions/workflows/release.yaml/badge.svg)](https://github.com/riotkit-org/waf-proxy/actions/workflows/release.yaml)

Notice: This container is still a WORK IN PROGRESS
--------------------------------------------------

Simple WAF reverse-proxy using Caddy and CORAZA WAF, contains few predefined but customizable rulesets

**Features:**
- Configurable mapping of backends to domains
- Contains embedded rulesets e.g. OWASP Core Ruleset, Wordpress-specific
- Kubernetes and cloud native
- Perfectly integrates with Wordpress and not only
- Non-root container (running as `uid=65161`)
- Real [distroless image based on scratch](https://hub.docker.com/_/scratch) **with only 2 binaries and few config files inside**
- Image is scanned for vulnerabilities on each release using Trivy Scanner
- Developed purely in Golang, [even entrypoint script was written in Golang instead of Bash](container-files/opt/build/entrypoint/entrypoint.go)
- Autonomous image, actively maintained by [Dependabot](https://github.com/dependabot) ;-)
- Limiting requests rate to protect against DoS
- (todo) Helm Chart for Kubernetes
- (todo) Strict Pod Security Policy that should run on OpenShift


Configuration reference
-----------------------

### Picking a version

We recommend you to pick a versioned release, snapshot version is only for testing for contributors.

List of versions you can find always there: https://github.com/riotkit-org/waf-proxy/pkgs/container/waf-proxy

```bash
docker pull ghcr.io/riotkit-org/waf-proxy:{select-your-version}
```

### Exposed ports

- 8081: Health check at `/` endpoint
- 8090: Proxied upstreams through WAF, HTTP port
- 2019: Metrics

### Directory structure

- `/etc/caddy/rules/coraza-recommended`
- `/etc/caddy/rules/riotit-org-basic`
- `/etc/caddy/rules/wordpress`
- `/etc/caddy/rules/owasp-crs`
- `/etc/caddy/rules/custom.conf` (extra configuration inside `coraza_waf` block)
- `/etc/caddy/custom-upstream.conf` (extra configuration outside `coraza_waf` block, but inside host block, before `reverse_proxy`, requires `ENABLE_CUSTOM_UPSTREAM_CONF=true`)

To add specific rules mount a docker volume or Kubernetes ConfigMap at `/etc/caddy/rules/custom/rules.conf`

### Environment variables

```yaml
#
# Upstreams
#
UPSTREAM_1: '{"pass_to": "http://my-service.default.svc.cluster.local", "hostname": "wordpress.org"}'
UPSTREAM_2: '...'
UPSTREAM_...: '...'

# to disable generation of Caddyfile you can set this variable to 'true' and mount Caddyfile under "/etc/caddy/Caddyfile"
# you can also still use it with 'false' with a custom template mounted under "/etc/caddy/Caddyfile.j2"
OWN_CADDYFILE: false
DEBUG: false  # enable extra verbosity, configuration printing to stdout
ENABLE_CUSTOM_UPSTREAM_CONF: false

# rate limiting - how many events are allowed in given time window?
# docs: https://github.com/mholt/caddy-ratelimit
ENABLE_RATE_LIMITER: false
RATE_LIMIT_EVENTS: 30
RATE_LIMIT_WINDOW: 5s

# allows to disable CORAZA WAF at all together with all rules
# helpful if wanting to use only other Caddy plugins
ENABLE_CORAZA_WAF: true

#
# Wordpress specific rules
#
# Sources:
#   - https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/02-INITIALIZATION.conf
#   - https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/03-BRUTEFORCE.conf
#   - https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/04-EVENTS.conf
#   - https://raw.githubusercontent.com/SEC642/modsec/master/rules/slr_rules/modsecurity_crs_46_slr_et_wordpress_attacks.conf
#

ENABLE_RULE_WORDPRESS: false
WP_CLIENT_IP: "remote-addr"  # x-forwarded-for, remote-addr or cf-connecting-ip
WP_ENABLE_BRUTEFORCE_MITIGATION: true
WP_BRUTEFORCE_TIMESPAN: 600
WP_BRUTEFORCE_THRESHOLD: 5
WP_BRUTEFORCE_BAN_PERIOD: 300
WP_ENABLE_XMLRPC: false
WP_ENABLE_USER_ENUMERATION: false
WP_ENABLE_DOS_PROTECTION: true
WP_HARDENED: true # enables a extra ruleset: https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/05-HARDENING.conf

#
# CORAZA-recommended preset
#
ENABLE_RULE_CORAZA_RECOMMENDED: false

#
# RiotKit Basic preset
#
ENABLE_RULE_RIOTKIT_ORG_BASIC: false


#
# OWASP Core Ruleset (CRS)
#
ENABLE_CRS: false
```


Rulesets
--------

### ENABLE_RULE_WORDPRESS

**Enables Wordpress-specific rules to protect against:**
- Brute force
- Access to files that should not be published
- Known vulnerabilities

**Sources:**
- https://github.com/Rev3rseSecurity/wordpress-modsecurity-ruleset
- https://github.com/SEC642/modsec


### ENABLE_RULE_CORAZA_RECOMMENDED

Basic rules provided by CORAZA WAF **in dry-run only mode**.

https://github.com/corazawaf/coraza/blob/v2/master/coraza.conf-recommended

### ENABLE_RULE_RIOTKIT_ORG_BASIC

The same rules as provided by CORAZA WAF, but not in dry-run mode and with increased upload filesize to 1GB.

### ENABLE_CRS

OWASP Core Ruleset - https://github.com/coreruleset/coreruleset/

```
The OWASP ModSecurity Core Rule Set (CRS) is a set of generic attack detection rules for use 
with ModSecurity or compatible web application firewalls. The CRS aims to protect web 
applications from a wide range of attacks, including the OWASP Top Ten, with a minimum of false alerts.
```

Versioning
----------

Docker image tag contains a chained version information.

**Example:**

`waf-proxy:2.5.1-coraza-v1.2.0-bv1.0.0`

**Explanation of this example:**
- 2.5.1: Caddy server version
- v1.2.0: CORAZA Caddy plugin version
- v1.0.0: This repositry tag

Autonomous image
----------------

This image is rebuilt automatically, when new version of Caddy, Coraza WAF or Golang version is released.

**Dependabot is bumping:**
- Caddy version in Dockerfile
- XCaddy version in Dockerfile
- Coraza WAF in `container-files/opt/build/caddy/go.sum` - created a dummy entry for Dependabot
- Golang builder in Dockerfile

Each Dependabot PR is automatically merged, when tests are passing.
