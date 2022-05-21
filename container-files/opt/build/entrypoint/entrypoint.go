package main

import (
	"encoding/json"
	"fmt"
	"github.com/flosch/pongo2/v5"
	"github.com/pkg/errors"
	"log"
	"os"
	"os/exec"
	"strings"
)

const caddyFileSrc = "/usr/templates/Caddyfile.j2"
const caddyFilePath = "/etc/caddy/Caddyfile"

const wpFileSrc = "/usr/templates/wp-rules.conf.j2"
const wpFilePath = "/etc/caddy/rules/wordpress/rules.conf"

func main() {
	usesOwnCaddyfile := getEnv("OWN_CADDYFILE", false).(bool)
	usesWordpressRules := getEnv("ENABLE_RULE_WORDPRESS", false).(bool)
	debug := getEnv("DEBUG", false).(bool)
	renderer := renderer{debug: debug}
	if err := renderer.populateUpstreams(os.Environ()); err != nil {
		log.Fatal(err)
	}
	renderer.buildPongoContext()

	if usesWordpressRules {
		if err := renderer.renderFile(wpFileSrc, wpFilePath); err != nil {
			log.Fatalf("Cannot render Wordpress Ruleset: %v", err)
		}
	}

	if !usesOwnCaddyfile {
		if err := renderer.renderFile(caddyFileSrc, caddyFilePath); err != nil {
			log.Fatalf("Cannot render Caddyfile: %v", err)
		}
	}

	if len(os.Args) < 3 {
		log.Fatalf("Need to provide at least 2 arguments e.g. /usr/bin/caddy run -pidfile /tmp/pid -config /etc/caddy/Caddyfile")
	}

	// run caddy server
	caddy := exec.Command(os.Args[1], os.Args[2:]...)
	caddy.Stdout = os.Stdout
	caddy.Stdin = os.Stdin
	caddy.Stderr = os.Stderr

	if err := caddy.Run(); err != nil {
		log.Fatalf("Process exited with error: %v", err)
	}
}

type renderer struct {
	upstreams []Upstream
	ctx       pongo2.Context
	debug     bool
}

func (r *renderer) renderFile(sourcePath string, targetPath string) error {
	template := pongo2.Must(pongo2.FromFile(sourcePath))
	out, err := template.Execute(r.ctx)
	if err != nil {
		return errors.Wrapf(err, "Cannot parse file '%v'", sourcePath)
	}

	r.printDebug(targetPath + ":")
	r.printDebug(out)

	if err := os.WriteFile(targetPath, []byte(out), os.FileMode(0755)); err != nil {
		return errors.Wrapf(err, "Cannot write into file %v", targetPath)
	}

	return nil
}

func (r *renderer) buildPongoContext() {
	ctx := pongo2.Context{}

	// environment variable = regular variable
	for _, env := range os.Environ() {
		pair := strings.SplitN(env, "=", 2)
		ctx[pair[0]] = getEnv(pair[0], "")
	}

	// all collected upstreams are internally objects
	ctx["upstreams"] = r.upstreams

	r.printDebug("Context:", ctx)

	r.ctx = ctx
}

func (r *renderer) populateUpstreams(environ []string) error {
	var upstreams []Upstream

	// collect upstream configuration
	for _, env := range environ {
		pair := strings.SplitN(env, "=", 2)
		r.printDebug("DEBUG: Checking environment variable if is upstream", env)

		if strings.Contains(pair[0], "UPSTREAM_") {
			if pair[1] == "" {
				continue
			}

			upstream := &Upstream{}

			r.printDebug("DEBUG: Creating upstream from ", env)

			err := json.Unmarshal([]byte(pair[1]), upstream)
			if err != nil {
				return errors.Wrapf(err, "Cannot parse upstream configuration from: %v", env)
			}

			upstreams = append(r.upstreams, *upstream)
		} else {
			r.printDebug("DEBUG: not an upstream", env)
		}
	}

	if len(upstreams) == 0 {
		return errors.New("No upstream defined. Create environment variables e.g. UPSTREAM_1, UPSTREAM_2 and assign them a JSON with pass_to and hostname keys")
	}

	r.upstreams = upstreams
	return nil
}

func (r *renderer) printDebug(text ...interface{}) {
	if r.debug {
		fmt.Println(text...)
	}
}

func getEnv(name string, defaultValue interface{}) interface{} {
	value, exists := os.LookupEnv(name)
	if !exists {
		return defaultValue
	}
	if value == "1" || value == "true" || value == "TRUE" || value == "yes" || value == "YES" || value == "Y" || value == "y" {
		return true
	}
	if value == "0" || value == "false" || value == "FALSE" || value == "no" || value == "NO" || value == "N" || value == "n" {
		return false
	}
	return value
}

type Upstream struct {
	PassTo   string `json:"pass_to"`
	Hostname string `json:"hostname"`
}
