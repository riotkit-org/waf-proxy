package main

import (
	"github.com/smallstep/assert"
	"testing"
)

func TestPopulateStreams(t *testing.T) {
	renderer := renderer{debug: false}
	err := renderer.populateUpstreams([]string{
		"UPSTREAM_1={\"pass_to\": \"http://127.0.0.1:8001\", \"hostname\": \"example.org\"}",
	})

	assert.Nil(t, err)
	assert.Equals(t, "example.org", renderer.upstreams[0].Hostname)
	assert.Equals(t, "http://127.0.0.1:8001", renderer.upstreams[0].PassTo)
}
