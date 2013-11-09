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

server_name=citysdk


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

citysdk_root=/var/www/citysdk

# This should be the same as the default prefix suggested by the
# interactive Passenger installation.
nginx_prefix=/opt/nginx

osm2pgsql_name=osm2pgsql
osm2pgsql_path=${osm2pgsql_name}

rvm_root=${HOME}/.rvm
rvm_bin=${rvm_root}/bin/rvm


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

function aptgetwrap()
{
    sudo apt-get --assume-yes --no-install-recommends "${@}"
}

function pg()
{
    sudo -u postgres "${@}"
}


function psql()
{
    pg psql "${db_name}" "${@}"
}

function rvmdo()
{
    # The 'do' argument does not need to be quoted. However, as a shell
    # keyword, unquoted it messes up syntax highlighting.
    "${rvm_bin}" "${ruby_version}" 'do' "${@}"
}

function rvmdo-passenger-root()
{
    rvmdo passenger-config --root
}

function rvmdo-passenger-ruby()
{
    # XXX: There must be cleaner way of getting the path of the Ruby
    #      binary.
    rvmdo passenger-config --ruby-command                                     \
        | grep --only-matching 'passenger_ruby.*'                             \
        | cut --delimiter=' ' --fields=2
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

# = Aptitude ==================================================================

function aptitude-curl()
{
    # cURL is required by the PostgreSQL repository
    aptgetwrap install curl
}

function aptitude-ppas()
{
    # PostgreSQL
    local "codename=$(lsb_release --codename --short)"
    sudo tee /etc/apt/sources.list.d/pgdg.list <<-EOF
		deb http://apt.postgresql.org/pub/repos/apt/ ${codename}-pgdg main
	EOF
    local 'url=http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
    curl "${url}" | sudo apt-key add -
}

function aptitude-update()
{
    aptgetwrap update
}

function aptitude-install()
{
    aptgetwrap install "${aptitude[@]}"
}

function aptitude-upgrade()
{
    aptgetwrap dist-upgrade
    aptgetwrap autoremove
}


# = RVM ======================================================================

function rvm-install()
{
   # XXX: Is it a good idea to install a user RVM (as opposed to a
   #      system RVM) when Nginx will installed globally and its config
   #      will reference citysdk's home directory (passenger_root and
   #      passenger_ruby)?
   curl --location https://get.rvm.io | bash -s stable
}

function rvm-requirements()
{
    sudo "${rvm_bin}" requirements
}

function rvm-ruby()
{
    "${rvm_bin}" install "${ruby_version}"
}

function rvm-gems()
{
    rvmdo gem install                                                         \
        --no-ri                                                               \
        --no-rdoc                                                             \
        --verbose                                                             \
        passenger                                                             \
        --version '~>4.0.23'
}


# = CitySDK ===================================================================

function citysdk-root()
{
    sudo mkdir --parents "${citysdk_root}"
    sudo chown --recursive "${user}:${group}" "${citysdk_root}"
}


# = Nginx =====================================================================

function nginx-install()
{
    # The prefix is the default but passing it prevents the installer
    # prompting the user.
    rvmdo rvmsudo passenger-install-nginx-module                              \
        --auto                                                                \
        --auto-download                                                       \
        "--prefix=${nginx_prefix}"
}

function nginx-conf()
{
    sudo tee /opt/nginx/conf/nginx.conf <<-EOF
		worker_processes  6;
		user ${user};

		events {
		    worker_connections 1024;
		}

		http {
		    passenger_root $(rvmdo-passenger-root);
		    passenger_ruby $(rvmdo-passenger-ruby);
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
		        server_name ${server_name};
		        root        ${citysdk_root}/current/public;

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

		    passenger_pre_start http://${server_name};
		}
	EOF
}

function nginx-service()
{
    local path=/etc/init.d/nginx
    local url=http://library.linode.com/assets/660-init-deb.sh

    sudo wget --output-document "${path}" "${url}"
    sudo chmod +x "${path}"
    sudo update-rc.d -f nginx defaults
}


# = Database ==================================================================

function db-create()
{
    # XXX: Always succeeding may mask problems. Instead query for the
    #      database and only create it if it does not exist.
    pg createdb "${db_name}" || true
}


function db-extensions()
{
    psql <<-"EOF"
		CREATE EXTENSION IF NOT EXISTS hstore;
		CREATE EXTENSION IF NOT EXISTS pg_trgm;
		CREATE EXTENSION IF NOT EXISTS postgis;
	EOF
}


# = osm2pgsql =================================================================

function osm2pgsql-clone()
{
    if [[ ! -d "${osm2pgsql_path}" ]]; then
        local "url=https://github.com/openstreetmap/${osm2pgsql_name}.git"
        git clone "${url}" "${osm2pgsql_path}"
    fi
}

function osm2pgsql-checkout()
{(
    cd -- "${osm2pgsql_path}"
    git checkout "${osm2pgsql_tag}"
)}

function osm2pgsql-configure()
{(
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

function osm2pgsql-build()
{(
    cd -- "${osm2pgsql_path}"
    make "--jobs=$(nproc)"
)}

function osm2pgsql-install()
{(
    cd -- "${osm2pgsql_path}"
    sudo make install
)}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    aptitude-curl
    aptitude-ppas
    aptitude-update
    aptitude-install
    aptitude-upgrade

    rvm-install
    rvm-requirements
    rvm-ruby
    rvm-gems

    citysdk-root

    nginx-install
    nginx-conf
    nginx-service

    db-create
    db-extensions

    osm2pgsql-clone
    osm2pgsql-checkout
    osm2pgsql-configure
    osm2pgsql-build
    osm2pgsql-install
)

function usage()
{
    cat <<-'EOF'
		Perform server deployment tasks

		Usage:

		    server.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Tasks:

		    ID  Name
		    1   aptitude-curl
		    2   aptitude-ppas
		    3   aptitude-update
		    4   aptitude-install
		    5   aptitude-upgrade
		    6   rvm-install
		    7   rvm-requirements
		    8   rvm-ruby
		    9   rvm-gems
		    10  citysdk-dirs
		    11  nginx-install
		    12  nginx-conf
		    13  nginx-service
		    14  db-create
		    15  db-extensions
		    16  osm2pgsql-clone
		    17  osm2pgsql-checkout
		    18  osm2pgsql-configure
		    19  osm2pgsql-build
		    20  osm2pgsql-install
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
    echo -e "\e[5;32mTask: ${task}\e[0m\n"
    ${task}
done

