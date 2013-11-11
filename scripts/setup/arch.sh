#!/usr/bin/env bash

set -o errexit
set -o nounset


# =============================================================================
# = Configuration                                                             =
# =============================================================================

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/../..")

ruby_version=1.9.3

packages=(
    'git'
    'virtualbox'
)


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

function rvmdo()
{
    "${HOME}/.rvm/bin/rvm" "${ruby_version}" 'do' "${@}"
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

function packages-install()
{
    sudo pacman --needed --noconfirm --refresh --sync "${packages[@]}"
}

function ruby-rvm()
{
    sudo sed -i '/gem: --user-install/d' /etc/gemrc
    curl --location  https://get.rvm.io                                       \
        | bash -s stable "--ruby=${ruby_version}"
}

function ruby-gems()
{
    for app in cms server; do
        rvmdo bundle install "--gemfile=${repo}/${app}/Gemfile"
    done
}

function config-init()
{
    local config=${repo}/config
    local template=${config}/config.template.json
    local config_local=${config}/local
    mkdir --parent "${config_local}"
    cp "${template}" "${config_local}/development.json"
    cp "${template}" "${config_local}/production.json"
    touch "${config_local}/production_hostname.txt"
}

function config-ln()
{
    local dir
    for dir in cms server; do
        local dst="${repo}/${dir}/config.json"
        if [[ ! -h "${dst}" ]]; then
            ln -s ../config/local/development.json "${dst}"
        fi
    done
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    packages-install
    ruby-rvm
    ruby-gems
    config-init
    config-ln
)

usage() {
    cat <<-'EOF'
		Install development dependencies and initialise repository

		Usage:

		    arch.sh [-s TASK_ID | [TASK_ID...]]

		    -s  Start from TASK_ID

		Tasks:

		    ID  Description
		    1   packages-install
		    2   ruby-rvm
		    3   ruby-gems
		    4   config-init
		    5   config-ln
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

