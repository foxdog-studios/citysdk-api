#!/bin/bash

# Copyright 2013 Foxdog Studios
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset


# =============================================================================
# = Configuration                                                             =
# =============================================================================

postgresql_version=9.3

postgis_version=2.1

osm2pgsql_tag=v0.82.0

db_name=citysdk


# = Site specific configuration ===============================================

source "$(dirname "$(readlink -f -- ${BASH_SOURCE[0]})")/config.sh"


# = Packages ==================================================================

aptitude=(
    # PostgreSQL
    "postgresql-${postgresql_version}"
    "postgresql-contrib-${postgresql_version}"

    # PostGIS
    "postgresql-${postgresql_version}-postgis-${postgis_version}"

    # osm2pgsql
    'autoconf'
    'g++'
    'git'
    'libbz2-dev'
    'libgeos++-dev'
    'libpq-dev'
    'libprotobuf-c0-dev'
    'libtool'
    'libxml2-dev'
    "postgresql-server-dev-${postgresql_version}"
    'proj'
    'protobuf-c-compiler'
    'zlib1g-dev'

    # Memcached
    'memcached'
)

gems=(
    'passenger -v 4.0.23'
)


# = Paths =====================================================================

osm2pgsql_name=osm2pgsql

osm2pgsql_path=${osm2pgsql_name}


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

apt-get() {
    sudo apt-get --assume-yes "${@}"
}


codename() {
    lsb_release --codename --short
}


ensure_build() {
    mkdir -p "${build_path}"
}


pg() {
    sudo -u postgres "${@}"
}


psql() {
    pg psql "${db_name}" "${@}"
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

# = Aptitude (1) ==============================================================

aptitude_curl() {
    # cURL is required by postgresql_ppa and RVM
    apt-get install curl
}


# = PostgreSQL ================================================================

postgresql_ppa() {
    sudo tee /etc/apt/sources.list.d/pgdg.list <<-EOF
		deb http://apt.postgresql.org/pub/repos/apt/ $(codename)-pgdg main
	EOF
    local 'url=http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
    curl "${url}" | sudo apt-key add -
}


# = Aptitude (2) ==============================================================

aptitude_update() {
    apt-get update
}


aptitude_install() {
    apt-get install "${aptitude[@]}"
}


aptitude_upgrade() {
    apt-get dist-upgrade
    apt-get autoremove
}


# = osm2pgsql =================================================================

osm2pgsql_clone() {
    ensure_build
    if [[ ! -d "${osm2pgsql_path}" ]]; then
        local "url=https://github.com/openstreetmap/${osm2pgsql_name}.git"
        git clone "${url}" "${osm2pgsql_path}"
    fi
}


osm2pgsql_checkout() {(
    cd -- "${osm2pgsql_path}"
    git checkout "${osm2pgsql_tag}"
)}


osm2pgsql_configure() {(
    cd -- "${osm2pgsql_path}"
    ./autogen.sh
    ./configure
    patch Makefile <<-"EOF"
		229c229
		< CFLAGS = -g -O2
		---
		> CFLAGS = -O2 -march=native -fomit-frame-pointer
		235c235
		< CXXFLAGS = -g -O2
		---
		> CXXFLAGS = -O2 -march=native -fomit-frame-pointer
	EOF
)}


osm2pgsql_build() {(
    cd -- "${osm2pgsql_path}"
    make "--jobs=$(nproc)"
)}


osm2pgsql_install() {(
    cd -- "${osm2pgsql_path}"
    sudo make install
)}


# = Ruby ======================================================================

ruby_gemrc() {
    sudo tee /etc/gemrc <<< 'gem: --no-rdoc --no-ri'
}


ruby_rvm() {
    sudo -s <<-EOF
		set -o errexit
		set -o nounset
		curl -L https://get.rvm.io | bash -s stable --rails
	EOF
}


ruby_gems() {
    for gem in "${gems[@]}"; do
        sudo -s <<-EOF
			set -o errexit
			source /usr/local/rvm/scripts/rvm
			gem install --verbose ${gem}
		EOF
    done
}


ruby_passenger() {
    sudo -s <<-'EOF'
		set -o errexit
		source /usr/local/rvm/scripts/rvm
		cd -- "$(passenger-config --root)"
		./bin/passenger-install-nginx-module \
		        --auto                       \
		        --auto-download              \
		        --prefix=/usr/local/nginx
	EOF
}


# = Database ==================================================================

db_create() {
    # XXX: Always succeeding may mask problems. Instead query for the
    #      database and only create it if it does not exist.
    pg createdb "${db_name}" || true
}


db_extensions() {
    psql <<-"EOF"
		CREATE EXTENSION IF NOT EXISTS hstore;
		CREATE EXTENSION IF NOT EXISTS pg_trgm;
		CREATE EXTENSION IF NOT EXISTS postgis;
	EOF
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    aptitude_curl

    postgresql_ppa

    aptitude_update
    aptitude_install
    aptitude_upgrade

    osm2pgsql_clone
    osm2pgsql_checkout
    osm2pgsql_configure
    osm2pgsql_build
    osm2pgsql_install

    ruby_gemrc
    ruby_rvm
    ruby_gems
    ruby_passenger

    db_create
    db_extensions
)

usage() {
    cat <<-'EOF'
		Perform server deployment tasks

		Usage:

		    server.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Tasks:

		    ID  Name
		    1   aptitude_curl
		    2   postgresql_ppa
		    3   aptitude_update
		    4   aptitude_install
		    5   aptitude_upgrade
		    6   osm2pgsql_clone
		    7   osm2pgsql_checkout
		    8   osm2pgsql_configure
		    9   osm2pgsql_build
		    10  osm2pgsql_install
		    11  ruby_gemrc
		    12  ruby_rvm
		    13  ruby_gems
		    14  ruby_passenger
		    15  db_create
		    16  db_extensions
	EOF
    exit 1
}

start_index=0

while getopts :s: opt; do
    case "${opt}" in
        s) start_index=$[ OPTARG - 1 ] ;;
        \?|*) usage ;;
    esac
done

shift $[ OPTIND - 1 ]

tasks=()
if [[ "${#}" == 0 ]]; then
    tasks+=( "${all_tasks[@]:${start_index}}" )
else
    for task_id in "${@}"; do
        tasks+=( "${all_tasks[$[ task_id - 1 ]]}" )
    done
fi

for task in "${tasks[@]}"; do
    ${task}
done

