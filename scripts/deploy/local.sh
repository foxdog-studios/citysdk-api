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

ruby_version=1.9.2


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

rvmshell() {
    # If RVM has just been installed, the user needs to log out and
    # back in for it to work. We get around this by running rvm
    # inside a new login shell.
    bash --login -s <<< "rvm use ${ruby_version}; ${@}"
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

server_deploy() {(
    cd -- "${path_repo}/server"
    rvmshell cap production deploy
)}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    'server_deploy'
)

usage() {
    cat <<-'EOF'
		Perform local deployment tasks

		Usage:

		    local.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Task:

		    ID  Name
		    1   Deploy the server
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

