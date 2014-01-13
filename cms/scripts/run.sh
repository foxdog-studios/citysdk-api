#!/usr/bin/env bash

set -o errexit
set -o nounset

cd "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/.."

port=$(underscore extract 'ep_cms_port' --outfmt text < config.json)

exec rvm 1.9.3@citysdk do bundle exec rackup -p $port

