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

path_repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/../..")

ruby_version=1.9.3


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

cap() {
    cd -- "${path_repo}/server"
    command cap production "${@}"
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

citysdk_setup() {
    cap deploy:setup deploy:check
}

citysdk_deploy() {
    cap deploy
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    citysdk_setup
    citysdk_deploy
)

usage() {
    cat <<-'EOF'
		Perform local deployment tasks

		Usage:

		    local.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Task:

		    ID  Name
		    1   Setup the production target
		    2   Deploy onto the production target
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

