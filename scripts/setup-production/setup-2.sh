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

# Load common config
source "$(dirname "$(readlink -f -- "${BASH_SOURCE[0]}")")/config.sh"

# =============================================================================
# = Configuration                                                             =
# =============================================================================

deploy_name=deploy
osm_data_pbf=/var/tmp/osm-data.pbf
ruby_version=1.9.3

citysdk_current=/var/www/citysdk/current
citysdk_db_root="${citysdk_current}/db"


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

function migration()
{(
    cd -- "${citysdk_db_root}"
    sudo -u postgres /usr/local/rvm/bin/rvm "${ruby_version}" do              \
        bundle exec ./run_migrations.rb "${@}"
)}

function psqlwrap()
{
    local database="${1}"
    local cmd="${2}"
    sudo -u postgres psql "--command=${cmd}" "${database}"
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

function deploy-delete_password()
{
    sudo passwd --delete "${deploy_name}"
}

function nginx-restart()
{
    # Passing restart does not start Nginx if it is not already
    # running. So, we explicitly stop (no effect if already stopped)
    # and then start.
    sudo service nginx stop || true
    sudo service nginx start
}

function ensure-db-user()
{
    # Does this user already exist?
    local query="SELECT 1 FROM pg_roles WHERE rolname='${db_user}'"
    if psqlwrap postgres "${query}" | grep --quiet 1; then
        return
    fi

    psqlwrap postgres "CREATE USER ${db_user} PASSWORD '${db_pass}'"
}

function osm-data()
{
    if [[ ! -f "${osm_data_pbf}" ]]; then
        curl --location -o "${osm_data_pbf}" "${osm_data_url}"
    fi

    expect -f - <<-EOF
		set timeout -1
		spawn osm2pgsql                                                       \
		    --cache "${osm2pgsql_cache_size_mb}"                              \
		    --database "${db_name}"                                           \
		    --host "${db_host}"                                               \
		    --hstore-all                                                      \
		    --latlong                                                         \
		    --password                                                        \
		    --slim                                                            \
		    --username "${db_user}"                                           \
		    "${osm_data_pbf}"
		expect "Password:"
		send "${db_pass}\r"
		expect eof
	EOF
}

function osm-schema()
{
    # XXX: Instead of always succeeding, make the script idempotent.
    sudo -u postgres psql "${db_name}" < "${citysdk_db_root}/osm_schema.sql"  \
        || true
}

function run-migrations()
{
    psqlwrap "${db_name}" "GRANT ALL ON SCHEMA osm TO ${db_user}"

    # '0' resets something
    migration 0
    migration
}

function set-admin-password()
{(
    cd -- "${citysdk_current}"
    /usr/local/rvm/bin/rvm "${ruby_version}" 'do' bundle exec "${@}" racksh   \
        "Owner[0].createPW('${citysdk_app_admin_password}')"
)}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    deploy-delete_password
    nginx-restart
    ensure-db-user
    osm-data
    osm-schema
    run-migrations
    set-admin-password
)

function usage()
{
    cat <<-'EOF'
		Perform deployment tasks on the target machine

		Usage:

		    target-2.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Tasks:

		    ID  Name
		    1   deploy-delete_password
		    2   nginx-restart
		    3   ensure-db-user
		    4   osm-data
		    5   osm-schema
		    6   run-migrations
		    7   set-admin-password
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

