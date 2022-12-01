# ===========================================================================
# We take xcaddy binary from this image, so the Dependabot can bump it later
#
# Hint: Bump Xcaddy there
# ===========================================================================
FROM caddy:2.6.2-builder-alpine as xcaddy


# ============================================================================================================
# We take just the Caddy version there, so we will build this Caddy version using Xcaddy in builder container
#
# Hint: Bump Caddy version there
# ============================================================================================================
FROM docker.io/caddy:2.6.2-alpine as caddy
RUN command -v caddy
RUN caddy version | awk '{print $1}' > /caddy-version


# ================================================================
# Builder that produces artifacts for our distroless output image
#
# Hint: Bump Golang version there
# ================================================================
FROM golang:1.19.3-alpine as builder

RUN apk add --update make

COPY --from=xcaddy /usr/bin/xcaddy /usr/bin/xcaddy
COPY --from=caddy /caddy-version /caddy-version
ADD container-files/opt/build/caddy /opt/build/caddy

# -----------------------------------
# Build Caddy Server with CORAZA WAF
# -----------------------------------
WORKDIR /opt/build/caddy
RUN make caddy CADDY_VERSION=$(cat /caddy-version | tr -d '\n')

# -----------------------------------------------------------------------------------------------
# Build entrypoint (instead of Bash we use GO to avoid having Operating System inside container)
# -----------------------------------------------------------------------------------------------
ADD container-files/opt/build/entrypoint /opt/build/entrypoint
RUN cd /opt/build/entrypoint && make build install

# ------------------------------
# Download predefined WAF rules
# ------------------------------
ADD container-files/etc/caddy /etc/caddy
RUN wget -q https://raw.githubusercontent.com/corazawaf/coraza/v2/master/coraza.conf-recommended -O /etc/caddy/rules/coraza-recommended/rules.conf \
    && wget -q https://raw.githubusercontent.com/SEC642/modsec/master/rules/slr_rules/modsecurity_46_slr_et_wordpress.data -O /etc/caddy/rules/wordpress/shared/modsecurity_46_slr_et_wordpress.data \
    && wget -q https://raw.githubusercontent.com/SEC642/modsec/master/rules/slr_rules/modsecurity_crs_46_slr_et_wordpress_attacks.conf -O /etc/caddy/rules/wordpress/shared/crs-attacks.conf

RUN wget -q https://github.com/coreruleset/coreruleset/archive/refs/tags/v4.0.0-rc1.tar.gz -O /tmp/owasp.tar.gz \
    && cd /tmp && tar xvf owasp.tar.gz \
    && cd /tmp/coreruleset-* \
    && mv rules /etc/caddy/rules/owasp-crs \
    && rm /tmp/owasp.tar.gz

# ---------------
# Fix permissions
# ---------------
RUN mkdir -p /tmp /.config /.config/caddy \
    && touch /etc/caddy/Caddyfile /tmp/.pid /etc/caddy/rules/wordpress/rules.conf /etc/caddy/rules/owasp-crs/configured.conf /etc/caddy/rules/custom.conf /etc/caddy/custom-upstream.conf \
    && chown -R 65161:65161 /tmp /etc/caddy /.config


# ===========================================================================================
# Prepare target image with just environment variables, configuration files and few binaries
# ===========================================================================================
FROM scratch

ENV ENABLE_RULE_WORDPRESS=false \
    ENABLE_RULE_CORAZA_RECOMMENDED=false \
    ENABLE_RULE_RIOTKIT_ORG_BASIC=false \
    WP_CLIENT_IP=remote-addr \
    WP_ENABLE_BRUTEFORCE_MITIGATION=true \
    WP_BRUTEFORCE_TIMESPAN=600 \
    WP_BRUTEFORCE_THRESHOLD=5 \
    WP_BRUTEFORCE_BAN_PERIOD=300 \
    WP_ENABLE_XMLRPC=false \
    WP_ENABLE_USER_ENUMERATION=false \
    WP_ENABLE_DOS_PROTECTION=true \
    ENABLE_CORAZA_WAF=true \
    ENABLE_CRS=false \
    ENABLE_RULE_DRUPAL=false \
    ENABLE_RATE_LIMITER=false \
    RATE_LIMIT_EVENTS=30 \
    RATE_LIMIT_WINDOW=5s \
    OWN_CADDYFILE=false \
    DEBUG=false \
    CADDY_PORT=8090

# templates are rendered on entrypoint execution depending on environment variables provided by user
COPY container-files/usr/templates /usr/templates

# required for storing /tmp/pid file
COPY --from=builder /tmp /tmp
# autosave directory
COPY --from=builder /.config /.config
# builder has already fetched and unpacked rulesets from external sources
COPY --from=builder /etc/caddy /etc/caddy
COPY --from=builder /usr/bin/entrypoint /usr/bin/entrypoint
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# pre-validate default configuration


# <testing configuration>
ENV UPSTREAM_VALIDATION_TEST="{\"pass_to\": \"http://127.0.0.1:8080\", \"hostname\": \"example.org\"}" \
    DEBUG=true
RUN ["/usr/bin/entrypoint", "/usr/bin/caddy", "validate", "-config", "/etc/caddy/Caddyfile"]
ENV UPSTREAM_VALIDATION_TEST="" \
    DEBUG=false
# </testing configuration>

USER 65161
CMD ["/usr/bin/caddy", "run", "-pidfile", "/tmp/.pid", "-config", "/etc/caddy/Caddyfile"]

# health check
EXPOSE 8081
# http
EXPOSE 8090
# metrics
EXPOSE 2019

ENTRYPOINT ["/usr/bin/entrypoint"]
