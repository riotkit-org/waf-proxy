#!/bin/bash
set -e

CADDY_VERSION=$(cat Dockerfile | grep FROM | grep "as caddy" | cut -d":" -f2 | cut -d"-" -f1)
CADDY_WAF_VERSION=$(cat container-files/opt/build/caddy/go.sum |grep "github.com/corazawaf/coraza-caddy" |grep -v "go.mod" | awk '{print $2}')

echo -n "${CADDY_VERSION}-coraza-${CADDY_WAF_VERSION}"
