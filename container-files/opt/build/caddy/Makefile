caddy: build

install:
	go get

# Caddy version: Dockerfile contains "FROM" where the version is defined, the Dockerfile stores its version into "caddy-version" file, bumped by Dependabot
# Xcaddy version: Provided by Dockerfile, bumped by Dependabot
# CORAZA-Caddy version: go.sum contains coraza-caddy version, bumped by Dependabot
build:
	set -xe; \
	CORAZA_VERSION=$$(cat go.sum |grep "github.com/corazawaf/coraza-caddy" |grep -v "go.mod" | awk '{print $$2}'); \
	xcaddy build ${CADDY_VERSION} --output /usr/bin/caddy \
		--with github.com/corazawaf/coraza-caddy@$${CORAZA_VERSION} \
		--with github.com/mholt/caddy-ratelimit
