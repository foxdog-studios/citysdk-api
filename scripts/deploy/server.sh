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

ruby_version=1.9.3

db_name=citysdk

user=citysdk

group=citysdk


# = Site specific configuration ===============================================

source "$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")/config.sh"
# XXX: Move this to config.sh

site_host=citysdk


# = Packages ==================================================================

aptitude=(
    # PostgreSQL
    "postgresql-${postgresql_version}"
    "postgresql-contrib-${postgresql_version}"

    # PostGIS
    "postgresql-${postgresql_version}-postgis-${postgis_version}"

    # osm2pgsql
    'automake'
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

    # Passenger
    'libcurl4-openssl-dev'

    # Memcached
    'memcached'
)


# = Paths =====================================================================

osm2pgsql_name=osm2pgsql

osm2pgsql_path=${osm2pgsql_name}

citysdk_path_root=/var/www/citysdk
citysdk_path_releases=${citysdk_path_root}/releases
citysdk_path_shared=${citysdk_path_root}/shared

citysdk_paths=(
    "${citysdk_path_root}"
    "${citysdk_path_releases}"
    "${citysdk_path_shared}"
)


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

apt-get() {
    sudo apt-get --assume-yes --no-install-recommends "${@}"
}


pg() {
    sudo -u postgres "${@}"
}


psql() {
    pg psql "${db_name}" "${@}"
}


rvm_source() {
    set +o nounset
    source "${HOME}/.rvm/scripts/rvm"
    set -o nounset
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

# = Aptitude ==================================================================

aptitude_curl() {
    # cURL is required by the PostgreSQL repository
    apt-get install curl
}


aptitude_ppas() {
    # PostgreSQL
    local "codename=$(lsb_release --codename --short)"
    sudo tee /etc/apt/sources.list.d/pgdg.list <<-EOF
		deb http://apt.postgresql.org/pub/repos/apt/ ${codename}-pgdg main
	EOF
    local 'url=http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
    curl "${url}" | sudo apt-key add -
}


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


# = RVM ======================================================================


rvm_install() {
   curl --location https://get.rvm.io | bash -s stable
}

rvm_requirements() {(
    rvm_source
    rvmsudo rvm requirements
)}


rvm_ruby() {(
    rvm_source
    set +o nounset
    rvm install "${ruby_version}"
)}


function rvm_gems() {
    rvm 1.9.3 do gem install                                                  \
        --no-ri                                                               \
        --no-rdoc                                                             \
        --verbose                                                             \
        passenger                                                             \
        --version '~>4.0.23'
}


# = CitySDK ===================================================================

citysdk_dirs() {
    sudo mkdir -p /var/www/citysdk
    sudo chown -R citysdk:citysdk /var/www/citysdk
}


# = Nginx =====================================================================

nginx_install() {(
    rvm_source

    # The prefix is the default but passing it prevents the installer
    # prompting the user.
    rvmsudo passenger-install-nginx-module                                    \
        --auto                                                                \
        --auto-download                                                       \
        --prefix=/opt/nginx
)}


nginx_conf() {(
    rvm_source
    local "root=$(passenger-config --root)"
    local "ruby=$(passenger-config --ruby-command                             \
        | grep --only-matching 'passenger_ruby.*'                             \
        | cut --delimiter=' ' --fields=2
    )"

    sudo tee /opt/nginx/conf/nginx.conf <<-EOF
		worker_processes  6;
		user citysdk;

		events {
		    worker_connections 1024;
		}

		http {
		    passenger_root ${root};
		    passenger_ruby ${ruby};
		    passenger_show_version_in_header off;
		    passenger_max_pool_size 24;
		    passenger_pool_idle_time 10;
		    passenger_min_instances 4;
		    passenger_spawn_method smart;

		    server_tokens off;

		    upstream memcached {
		        server localhost:11211 weight=5 max_fails=3 fail_timeout=3s;
		        keepalive 1024;
		    }

		    include mime.types;
		    default_type  application/octet-stream;
		    log_format main '\$remote_addr "\$time_iso8601" "\$http_referer" "\$request" \$status \$body_bytes_sent';

		    sendfile on;
		    keepalive_timeout 65;

		    gzip             on;
		    gzip_min_length  1000;
		    gzip_proxied     expired no-cache no-store private auth;
		    gzip_types       text/plain application/xml application/json application/x-javascript;

		    # API over HTTP
		    server {
		        listen      80;
		        server_name citysdk;
		        root        ${citysdk_path_root}/current/public;

		        location = /favicon.ico {
		            access_log    off;
		            log_not_found off;
		            return        444;
		        }

		        location /get_session  {
		            return 404;
		        }

		        location = /robots.txt {
		            access_log    off;
		            log_not_found off;
		            return        444;
		        }

		        passenger_enabled on;
		    }

		    passenger_pre_start http://${site_host};
		}
	EOF
)}


nginx_service() {
    local path=/etc/init.d/nginx
    local url=http://library.linode.com/assets/660-init-deb.sh

    sudo wget --output-document "${path}" "${url}"
    sudo chmod +x "${path}"
    sudo update-rc.d -f nginx defaults
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


# = osm2pgsql =================================================================

osm2pgsql_clone() {
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


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    aptitude_curl
    aptitude_ppas
    aptitude_update
    aptitude_install
    aptitude_upgrade

    rvm_install
    rvm_requirements
    rvm_ruby
    rvm_gems

    citysdk_dirs

    nginx_install
    nginx_conf
    nginx_service

    db_create
    db_extensions

    osm2pgsql_clone
    osm2pgsql_checkout
    osm2pgsql_configure
    osm2pgsql_build
    osm2pgsql_install
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
		    2   aptitude_ppas
		    3   aptitude_update
		    4   aptitude_install
		    5   aptitude_upgrade
		    6   rvm_install
		    7   rvm_requirements
		    8   rvm_ruby
		    9   rvm_gems
		    10  citysdk_dirs
		    11  nginx_install
		    12  nginx_conf
		    13  nginx_service
		    14  db_create
		    15  db_extensions
		    16  osm2pgsql_clone
		    17  osm2pgsql_checkout
		    18  osm2pgsql_configure
		    19  osm2pgsql_build
		    20  osm2pgsql_install
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
    echo -e "\n\e[5;32mTask: ${task}\e[0m\n"
    ${task}
done

