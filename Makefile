IMAGE=waf-proxy

build:
	docker build . -t ${IMAGE}

test: test_wp test_no_upstreams test_crs test_riotkit_basic

test_riotkit_basic:
	docker run --rm --name waf-proxy \
		-e UPSTREAM_1='{"pass_to": "my-service.default.svc.cluster.local", "hostname": "example.org"}' \
		-e ENABLE_RULE_RIOTKIT_ORG_BASIC=true \
		-e DEBUG=true \
        ${IMAGE} caddy validate -config /etc/caddy/Caddyfile

test_crs:
	docker run --rm --name waf-proxy \
		-e UPSTREAM_1='{"pass_to": "my-service.default.svc.cluster.local", "hostname": "example.org"}' \
		-e ENABLE_CRS=true \
		-e DEBUG=true \
        ${IMAGE} caddy validate -config /etc/caddy/Caddyfile

test_no_upstreams:
	docker run --rm --name waf-proxy \
        ${IMAGE} caddy validate -config /etc/caddy/Caddyfile; \
    [[ "$$?" == "1" ]] || (echo "Validation should fail due to missing upstreams definition" && exit 1)

test_wp:
	docker run --rm --name waf-proxy \
		-e UPSTREAM_1='{"pass_to": "my-service.default.svc.cluster.local", "hostname": "wordpress.org"}' \
		-e UPSTREAM_2='{"pass_to": "my-other-service.default.svc.cluster.local", "hostname": "wordpress.org"}' \
		-e ENABLE_RULE_WORDPRESS=true \
        -e WP_CLIENT_IP=remote-addr \
        -e WP_ENABLE_BRUTEFORCE_MITIGATION=true \
        -e WP_BRUTEFORCE_TIMESPAN=300 \
        -e WP_BRUTEFORCE_THRESHOLD=5 \
        -e WP_BRUTEFORCE_BAN_PERIOD=300 \
        -e WP_ENABLE_XMLRPC=true \
        -e WP_ENABLE_USER_ENUMERATION=false \
        -e WP_ENABLE_DOS_PROTECTION=true \
        -e WP_HARDENED=true \
        -e ENABLE_CRS=true \
        -e DEBUG=true \
        ${IMAGE} caddy validate -config /etc/caddy/Caddyfile
