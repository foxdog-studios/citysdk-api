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

db_name=citysdk

deploy_name=deploy
nginx_name=www-data
group=www-data

osm2pgsql_tag=v0.82.0
passenger_version=4.0.23
postgis_version=2.1
postgresql_version=9.3
ruby_version=1.9.3


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
citysdk_current=${citysdk_root}/current
citysdk_public=${citysdk_current}/public
citysdk_releases=${citysdk_root}/releases
citysdk_shared=${citysdk_root}/shared
citysdk_paths=(
    "${citysdk_root}"
    "${citysdk_current}"
    "${citysdk_public}"
    "${citysdk_releases}"
    "${citysdk_shared}"
)

# This should be the same as the default prefix suggested by the
# interactive Passenger installation.
nginx_prefix=/opt/nginx
nginx_conf=${nginx_prefix}/conf/nginx.conf
nginx_log=/var/log/nginx
nginx_log_access=${nginx_log}/access.log
nginx_log_error=${nginx_log}/error.log
nginx_logs=(
    "${nginx_log_access}"
    "${nginx_log_error}"
)

osm2pgsql_name=osm2pgsql
osm2pgsql_path=${osm2pgsql_name}

rvm_root=/usr/local/rvm
rvm_bin=${rvm_root}/bin/rvm


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

function aptgetwrap()
{
    sudo apt-get --assume-yes --no-install-recommends "${@}"
}

function generate-password()
{
    tr --delete --complement 'a-z' < /dev/urandom                             \
        | head --bytes=12
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

function rvmsudo()
{
    rvmdo rvmsudo "${@}"
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


# = RVM =======================================================================

function rvm-install()
{
   # Multi-user RVM installation
   curl --location https://get.rvm.io | sudo bash -s stable
}

function rvm-requirements()
{
    sudo "${rvm_bin}" requirements
}

function rvm-ruby()
{
    sudo "${rvm_bin}" install "${ruby_version}"
}

function rvm-gems()
{
    rvmsudo gem install                                                       \
        --no-ri                                                               \
        --no-rdoc                                                             \
        --verbose                                                             \
        passenger                                                             \
        --version "~>${passenger_version}"
}


# = User ======================================================================

function user-ensure-deploy()
{
    if ! getent passwd "${deploy_name}"; then
        sudo useradd                                                          \
            --create-home                                                     \
            --gid "${group}"                                                  \
            --groups rvm                                                      \
            "${deploy_name}"

        # Generate, set and print deploy's password
        local password=$(generate-password)
        trap "echo deploy password: ${password}" EXIT
        sudo chpasswd <<< "${deploy_name}:${password}"
    fi
}


# = CitySDK ===================================================================

function citysdk-root()
{
    sudo mkdir --parents "${citysdk_paths[@]}"
    sudo chown --recursive "${deploy_name}:${group}" "${citysdk_root}"
}


# = Nginx =====================================================================

function nginx-install()
{
    # The prefix is the default but passing it prevents the installer
    # prompting the user.
    rvmsudo passenger-install-nginx-module                                    \
        --auto                                                                \
        --auto-download                                                       \
        "--prefix=${nginx_prefix}"
}

function nginx-logs()
{
    sudo mkdir --parents "${nginx_log}"
    local log
    for log in "${nginx_logs[@]}"; do
        sudo touch "${log}"
        sudo chmod g+w "${log}"
        sudo chown ":${group}" "${log}"
    done
}

function nginx-conf()
{
    sudo tee "${nginx_conf}" <<-EOF
		user ${nginx_name};

		events {
		    worker_connections 1024;
		}

		http {
		    passenger_root $(rvmdo-passenger-root);
		    passenger_ruby $(rvmdo-passenger-ruby);

		    server {
		        listen 80;
		        server_name ${server_name};
		        root ${citysdk_public};

		        access_log ${nginx_log_access};
		        error_log ${nginx_log_error};

		        passenger_enabled on;
		    }
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

    user-ensure-deploy

    citysdk-root

    nginx-install
    nginx-logs
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
		    10  user-ensure-deploy
		    11  citysdk-root
		    12  nginx-install
		    13  nginx-logs
		    14  nginx-conf
		    15  nginx-service
		    16  db-create
		    17  db-extensions
		    18  osm2pgsql-clone
		    19  osm2pgsql-checkout
		    20  osm2pgsql-configure
		    21  osm2pgsql-build
		    22  osm2pgsql-install
	EOF
    exit 1
}

start_index=

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
    if [[ -n "${start_index}" ]]; then
        usage
    fi
    for task in "${@}"; do
        if [[ "${task}" =~ ^[0-9]+$ ]]; then
            tasks+=( "${all_tasks[$[ task - 1 ]]}" )
        else
            tasks+=( "${task}" )
        fi
    done
fi

for task in "${tasks[@]}"; do
    echo -e "\e[5;32mTask: ${task}\e[0m\n"
    ${task}
done

