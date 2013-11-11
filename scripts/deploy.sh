#!/bin/bash

# Copyright 2013 Foxdog Studios
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset


# =============================================================================
# = Configration                                                              =
# =============================================================================

repo="$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/..")"

# Server must be deployed before any other applications
applications=(
    server
    cms
)

config_path="${repo}/config/local"

hostname="deploy@$(cat "${config_path}/production_hostname.txt")"

ruby_version=1.9.3

rvm_root="${HOME}/.rvm"

rvm_bin="${rvm_root}/bin/rvm"



# =============================================================================
# = Helpers                                                                   =
# =============================================================================

function capall()
{(
    local app
    for app in "${applications[@]}"; do
        cd -- "${repo}/${app}"
        "${rvm_bin}" "${ruby_version}" 'do' bundle 'exec' cap production "${@}"
    done
)}

function deploy-config()
{
    local app="${1}"
    local domain="${2:+${2}.}${hostname}"
    local dir="${repo}/${app}/config/deploy"
    mkdir --parents "${dir}"
    tee "${dir}/production.rb" <<-EOF
		server '${hostname}', :app, :web, :primary => true
	EOF
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

function deploy-config-all()
{
    deploy-config server
    deploy-config cms cms
}

function cap-setup-all()
{
    capall deploy:setup
}

function cap-check-all()
{
   capall deploy:check
}

function cap-deploy-all()
{
    capall deploy
}

function config-cp()
{
    local src="${config_path}/production.json"
    local dst='/var/www/citysdk/shared/config'
    ssh "${hostname}" mkdir --parents "${dst}"
    scp "${src}" "${hostname}:${dst}/config.json"
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    deploy-config-all
    cap-setup-all
    cap-check-all
    cap-deploy-all
    config-cp
)

usage() {
    cat <<-'EOF'
		Deploy to the production machine

		Usage:

		    deploy.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Task:

		    ID  Name
		    1   deploy-config-all
		    2   cap-setup-all
		    3   cap-check-all
		    4   cap-deploy-all
		    5   config-cp
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

