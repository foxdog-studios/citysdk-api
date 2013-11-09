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

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/../..")

ruby_version=1.9.3

rvm_root=${HOME}/.rvm

rvm_bin=${rvm_root}/bin/rvm


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

function cap()
{(
    cd -- "${repo}/server"
    "${rvm_bin}" "${ruby_version}" 'do' bundle 'exec' cap production "${@}"
)}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

function cap-setup()
{
    cap deploy:setup deploy:check
}

function cap-deploy()
{
    cap deploy
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    cap-setup
    cap-deploy
)

usage() {
    cat <<-'EOF'
		Perform local deployment tasks

		Usage:

		    local.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Task:

		    ID  Name
		    1   cap-setup
		    2   cap-deploy
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
        if [[ "${task}" =~ '^[0-9]+$' ]]; then
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

