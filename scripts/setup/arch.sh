#!/usr/bin/env bash

set -o errexit
set -o nounset


# =============================================================================
# = Configuration                                                             =
# =============================================================================

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/../..")

ruby_version=1.9.3

gems=(
    'capistrano     -v 2.15.4'
    'capistrano-ext -v 1.2.1 '
)

system_packages=(
    'git'
    'virtualbox'
)


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

install_system_packages() {
    sudo pacman --needed --noconfirm --refresh --sync "${system_packages[@]}"
}


install_rvm() {
    sudo sed -i '/gem: --user-install/d' /etc/gemrc
    curl -L https://get.rvm.io | bash -s stable "--ruby=${ruby_version}"
}


install_gems() {
    rvmshell bundle
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    install_system_packages
    install_rvm
    install_gems
)

usage() {
    cat <<-'EOF'
		Install development dependencies and initialise repository

		Usage:

		    arch.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Tasks:

		    ID  Description
		    1   Install system packages
		    2   Install RVM
		    3   Install gems
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

