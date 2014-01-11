#!/usr/bin/env bash

set -o errexit
set -o nounset


# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/..")

db_host=localhost
db_name=citysdk
db_user=citysdk
db_password=citysdk

# ==============================================================================
# = Helpers                                                                    =
# ==============================================================================

function pdo()
{
    sudo --login --user=postgres -- "$@"

}


function psql()
{
    pdo psql --command="$1" "${2:-$db_name}"
}


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function postgresql_delete_db()
{
    psql "DROP DATABASE IF EXISTS $db_name;" postgres
}

function postgresql_delete_user()
{
    psql "DROP USER IF EXISTS $db_user;" postgres
}

function postgres_run_all()
{
    $repo/scripts/setup.sh \
        postgresql_config \
        postgresql_create \
        postgresql_extensions \
        postgresql_user \
        postgresql_data \
        postgresql_import \
        postgresql_schema \
        postgresql_migrations
}


# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

all_tasks=(
    postgresql_delete_db
    postgresql_delete_user
    postgres_run_all
)

function usage()
{
    cat <<-'EOF'
		Set up a development environment

		Usage:

		    setup.sh [TASK... ]

		Tasks:

		    postgresql_delete_db
		    postgresql_delete_user
		    postgresql_run_all
	EOF
    exit 1
}


for task in "$@"; do
    if [[ "$(type -t "$task" 2> /dev/null)" != function ]]; then
        usage
    fi
done

for task in "${@:-${all_tasks[@]}}"; do
    echo -e "\e[5;32mTask: $task\e[0m"
    "$task"
done

