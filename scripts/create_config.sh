#!/usr/bin/env bash

set -o errexit
set -o nounset


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

function usage()
{
    cat <<-EOF
		Create JSON configuration files

		Usage:

		    create_config.sh
	EOF
    exit 1
}

while getopts : opt; do
    case "${opt}" in
        \?|*) usage ;;
    esac
done

shift $[ OPTIND - 1 ]

if [[ "${#}" != 0 ]]; then
    usage
fi


# =============================================================================
# = Create configuration files                                                =
# =============================================================================

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/..")

keys=(
    db_host
    db_name
    db_user
    db_pass

    ep_code
    ep_description
    ep_api_url
    ep_cms_url
    ep_info_url
    ep_services_url
    ep_tileserver_url
    ep_maintainer_email
    ep_mapxyz
)

function write_config()
{
    local src="${repo}/config/local/${1}.sh"
    local dst="${repo}/config/local/${1}.json"
    make_config "${src}" > "${dst}"
}

function make_config()
{
    local src=${1}
    source "${src}"
    echo '{'
    for key in "${keys[@]::$[ ${#keys[@]} - 1]}"; do
        make_entry "${key}"
    done
    make_entry_last "${keys[${#keys[@]} - 1]}"
    echo '}'
}

function make_entry()
{
    make_entry_inner "${@}"
    echo ,
}

function make_entry_last()
{
    make_entry_inner "${@}"
    echo
}

function make_entry_inner()
{
    local "key=${1}"
    eval "local value=\$${1}"
    echo -n "  \"${key}\": \"${value}\""
}

write_config development
write_config production

