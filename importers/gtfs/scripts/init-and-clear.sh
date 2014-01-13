#!/usr/bin/env bash

set -o errexit
set -o nounset

cd "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/.."
exec rvm 1.9.3@citysdk do ruby clear.rb

