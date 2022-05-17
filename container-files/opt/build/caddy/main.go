package main

import (
	"github.com/corazawaf/coraza-caddy"
)

func main() {
	// dummy: to make golang think it is a direct dependency
	//        really we need this for Dependabot, so it will bump coraza-caddy as a dependency time-to-time together with Dockerfile FROM's
	_ = coraza.Middleware{}
}
