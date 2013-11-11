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

deploy_name=deploy
osm_data_url=https://github.com/ibigroup/JourneyPlanner/blob/master/Ibi.JourneyPlanner.Web/App_Data/Manchester.osm.pbf?raw=true
osm_data_pbf=/var/tmp/osm-data.pbf

citysdk_current=/var/www/citysdk/current/
citysdk_db_root="${citysdk_current}/db/"

db_name=citysdk
db_user=postgres
db_host=localhost

cache_size_mb=800

admin_password='password'

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
    sudo service nginx stop
    sudo service nginx start
}

function ensure-db-user()
{
    sudo -u "${db_user}" -s <<-EOF
		psql postgres \
            -tAc  "SELECT 1 FROM pg_roles WHERE rolname='${db_user}'" \
            | grep -q 1 \
        || create_user --pwprompt ${db_user}
	EOF
}

function osm-data()
{
    if [[ ! -f ${osm_data_pbf} ]]; then
        curl -L -o ${osm_data_pbf} ${osm_data_url}
    fi
    cd /var/tmp
    osm2pgsql                                                                 \
        --cache "${cache_size_mb}"                                            \
        --database "${db_name}"                                               \
        --host "${db_host}"                                                   \
        --hstore-all                                                          \
        --latlong                                                             \
        --password ${osm_data_pbf}                                            \
        --slim                                                                \
        --username "${db_user}"
}

function osm-schema()
{(
    cd ${citysdk_db_root}
    sudo -u "${db_user}" psql                                                 \
        -d "${db_name}"                                                       \
        -U "${db_user}" < osm_schema.sql
)}

function run-migrations()
{
    /bin/bash --login -s <<-EOF
		rvm use 1.9.3
		cd ${citysdk_db_root}
		rvm 1.9.3 do ./run_migrations.rb 0
		rvm 1.9.3 do ./run_migrations.rb
	EOF
}

function set-admin-password()
{
    /bin/bash --login -s <<-EOF
		rvm use 1.9.3
		cd ${citysdk_current}
		racksh "o = Owner[0]; o.createPW('${admin_password}')"
	EOF
}

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

