# ===========================================================================
# We take xcaddy binary from this image, so the Dependabot can bump it later
#
# Hint: Bump Xcaddy there
# ===========================================================================
FROM caddy:2.5.0-builder-alpine as xcaddy


# ============================================================================================================
# We take just the Caddy version there, so we will build this Caddy version using Xcaddy in builder container
#
# Hint: Bump Caddy version there
# ============================================================================================================
FROM caddy:2.5.0-alpine as caddy
RUN caddy version | awk '{print $1}' > /caddy-version


# ================================================================
# Builder that produces artifacts for our distroless output image
#
# Hint: Bump Golang version there
# ================================================================
FROM golang:1.18.2-alpine as builder

RUN apk add --update make

COPY --from=xcaddy /usr/bin/xcaddy /usr/bin/xcaddy
COPY --from=caddy /caddy-version /caddy-version
ADD container-files/opt/build/caddy /opt/build/caddy

# -----------------------------------
# Build Caddy Server with CORAZA WAF
# -----------------------------------
WORKDIR /opt/build/caddy
RUN make caddy CADDY_VERSION=$(cat /caddy-version | tr -d '\n')

# ------------------------------
# Download predefined WAF rules
# ------------------------------
ADD container-files/etc/caddy /etc/caddy
RUN wget -q https://raw.githubusercontent.com/corazawaf/coraza/v2/master/coraza.conf-recommended -O /etc/caddy/rules/coraza-recommended/rules.conf \
    && wget -q https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/02-INITIALIZATION.conf -O /etc/caddy/rules/wordpress/shared/02-INITIALIZATION.conf \
    && wget -q https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/03-BRUTEFORCE.conf -O /etc/caddy/rules/wordpress/shared/03-BRUTEFORCE.conf \
    && wget -q https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/04-EVENTS.conf -O /etc/caddy/rules/wordpress/shared/04-EVENTS.conf \
    && wget -q https://raw.githubusercontent.com/Rev3rseSecurity/wordpress-modsecurity-ruleset/master/05-HARDENING.conf -O /etc/caddy/rules/wordpress/shared/05-HARDENING.conf \
    && wget -q https://raw.githubusercontent.com/SEC642/modsec/master/rules/slr_rules/modsecurity_46_slr_et_wordpress.data -O /etc/caddy/rules/wordpress/shared/modsecurity_46_slr_et_wordpress.data \
    && wget -q https://raw.githubusercontent.com/SEC642/modsec/master/rules/slr_rules/modsecurity_crs_46_slr_et_wordpress_attacks.conf -O /etc/caddy/rules/wordpress/shared/crs-attacks.conf

RUN wget -q https://github.com/coreruleset/coreruleset/archive/refs/tags/v3.3.2.tar.gz -O /tmp/owasp.tar.gz \
    && cd /tmp && tar xvf owasp.tar.gz \
    && cd /tmp/coreruleset-* \
    && mv rules /etc/caddy/owasp-crs \
    && rm /tmp/owasp.tar.gz

# -----------------------------------------------------------------------------------------------
# Build entrypoint (instead of Bash we use GO to avoid having Operating System inside container)
# -----------------------------------------------------------------------------------------------
ADD container-files/opt/build/entrypoint /opt/build/entrypoint
RUN cd /opt/build/entrypoint && make build install
RUN mkdir -p /tmp && touch /etc/caddy/Caddyfile /tmp/.keep && chown 65168:65168 /etc/caddy/Caddyfile /tmp/.keep


# ===========================================================================================
# Prepare target image with just environment variables, configuration files and few binaries
# ===========================================================================================
FROM scratch

ENV ENABLE_RULE_WORDPRESS=false \
    ENABLE_RULE_CORAZA_RECOMMENDED=false \
    ENABLE_RULE_RIOTKIT_ORG_BASIC=true \
    WP_CLIENT_IP=remote-addr \
    WP_ENABLE_BRUTEFORCE_MITIGATION=true \
    WP_BRUTEFORCE_TIMESPAN=600 \
    WP_BRUTEFORCE_THRESHOLD=5 \
    WP_BRUTEFORCE_BAN_PERIOD=300 \
    WP_ENABLE_XMLRPC=false \
    WP_ENABLE_USER_ENUMERATION=false \
    WP_ENABLE_DOS_PROTECTION=true \
    OWN_CADDYFILE=false \
    DEBUG=false

# templates are rendered on entrypoint execution depending on environment variables provided by user
COPY container-files/usr/templates /usr/templates

# required for storing /tmp/pid file
COPY --from=builder /tmp/.keep /tmp/.keep
# builder has already fetched and unpacked rulesets from external sources
COPY --from=builder /etc/caddy /etc/caddy
COPY --from=builder /usr/bin/entrypoint /usr/bin/entrypoint
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# pre-validate default configuration
RUN ["/usr/bin/entrypoint", "/usr/bin/caddy", "validate", "-config", "/etc/caddy/Caddyfile"]

USER 65168
CMD ["/usr/bin/caddy", "run", "-pidfile", "/tmp/pid", "-config", "/etc/caddy/Caddyfile"]
ENTRYPOINT ["/usr/bin/entrypoint"]
