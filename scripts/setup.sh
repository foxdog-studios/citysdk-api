#!/usr/bin/env bash

set -o errexit
set -o nounset


# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/..")

applications=(
    server
    cms
    rdf
    devsite
)

config_applications=(
    server
    cms
    devsite
)

data_dir=$repo/local
data_path=$data_dir/osm.pbf
data_url='https://github.com/ibigroup/JourneyPlanner/blob/master/'
data_url+='Ibi.JourneyPlanner.Web/App_Data/Manchester.osm.pbf?raw=true'

db_host=localhost
db_name=citysdk
db_user=citysdk
db_password=citysdk

packages_aur=(
    osm2pgsql-git
)

packages_official=(
    expect
    git
    libyaml
    postgresql
    yaourt
)

rvm_bin=~/.rvm/bin/rvm
rvm_gemset=citysdk

ruby_version=1.9.3


# ==============================================================================
# = Helpers                                                                    =
# ==============================================================================

function bundle()
{
    rvmdo bundle "$@"
}


function pdo()
{
    sudo --login --user=postgres -- "$@"

}


function psql()
{
    pdo psql --command="$1" "${2:-$db_name}"
}


function rvm()
{
    "$rvm_bin" "$ruby_version@$rvm_gemset" "$@"
}


function rvmdo()
{
    rvm 'do' "$@"
}


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function add_archlinuxfr_repo()
{
    if ! grep --quiet '\[archlinuxfr\]' /etc/pacman.conf; then
        sudo tee --append /etc/pacman.conf <<-'EOF'
			[archlinuxfr]
			Server = http://repo.archlinux.fr/$arch
			SigLevel = Never
		EOF
    fi
}


function packages_official_install()
{
    sudo pacman --noconfirm               \
                --sync                    \
                --needed                  \
                --refresh                 \
                "${packages_official[@]}"
}


function packages_aur_install()
{
    yaourt --noconfirm --sync --needed --refresh "${packages_aur[@]}"
}


function rvm_install()
{
    # /etc/gemrc is part of Arch Linux's Ruby package
    if [[ -f /etc/gemrc ]]; then
        sudo sed -i '/gem: --user-install/d' /etc/gemrc
    fi

    curl --location https://get.rvm.io | bash -s stable
}


function rvm_ruby()
{
    rvm install "ruby-$ruby_version"
}


function rvm_gemset()
{
    rvm gemset create "$rvm_gemset"

    local app
    for app in "${applications[@]}"; do
        echo Bundling: $app
        bundle install "--gemfile=$repo/$app/Gemfile"
    done
}


function postgresql_config()
{
    sudo systemd-tmpfiles --create postgresql.conf

    local data=/var/lib/postgres/data
    if [[ "$(pdo ls -1 "$data" | wc -l)" -eq 0 ]]; then
        pdo initdb --locale en_GB.UTF-8 -D "$data"
    fi

    sudo systemctl enable postgresql.service
    sudo systemctl start postgresql.service
}


function postgresql_create()
{
    local query="SELECT 1 FROM pg_database WHERE datname = '$db_name';"

    # Return is the database already exists
    if psql "$query" postgres | grep --quiet 1; then
        return
    fi

    pdo createdb "$db_name"
}


function postgresql_extensions()
{
    psql 'CREATE EXTENSION IF NOT EXISTS hstore;
          CREATE EXTENSION IF NOT EXISTS pg_trgm;
          CREATE EXTENSION IF NOT EXISTS postgis;'
}


function postgresql_data()
{
    mkdir --parent "$data_dir"

    if [[ ! -f "$data_path" ]]; then
        curl --location --output "$data_path" "$data_url"
    fi
}


function postgresql_user()
{
    local query="SELECT 1 FROM pg_roles WHERE rolname='$db_user';"

    # Does this user already exist?
    if psql "$query" postgres | grep --quiet 1; then
        return
    fi

    psql "CREATE USER $db_user PASSWORD '$db_password'" postgres
    psql "GRANT ALL ON DATABASE $db_name TO $db_user"
}


function postgresql_import()
{
    expect -f - <<-EOF
		set timeout -1
		spawn osm2pgsql           \
		    --cache 800           \
		    --database "$db_name" \
		    --host "$db_host"     \
		    --hstore-all          \
		    --latlong             \
		    --password            \
		    --slim                \
		    --username "$db_user" \
		    "$data_path"
		expect "Password:"
		send "$db_password\r"
		expect eof
	EOF
}


function postgresql_schema()
{
    # TODO: Instead of always succeeding, make the script idempotent.
    pdo psql "$db_name" < "$repo/server/db/osm_schema.sql" || true
}


function postgresql_migrations()
{
    psql "GRANT ALL ON SCHEMA osm TO $db_name;"

    function migration()
    {(
        cd "$repo/server/db"
        bundle exec ./run_migrations.rb "$@"
    )}

    # '0' resets something
    migration 0
    migration

    unset -f migration
}


function config_init()
{
    function cp_config()
    {
        local name=$1

        local config=$repo/config
        local template=$config/config.template.sh
        local config_local=$config/local
        local path=$config_local/$name

        mkdir --parent "$config_local"

        if [[ ! -f "$path" ]]; then
            cp "$template" "$path"
        else
            echo $name already exists, skipping
        fi
    }

    cp_config development
    cp_config production

    unset -f cp_config
}


function config_ln()
{
    local app

    for app in "${config_applications[@]}"; do
        echo Soft-linking config for: $app
        ln -f -s ../config/local/development.json "$repo/$app/config.json"
    done
}

function cms_set_admin_details()
{(
    cd "$repo/server"
    bundle exec racksh \
        "owner = Owner[0]
         owner.createPW('citysdk')
         owner.name='citysdk'
         owner.email='citysdk@example.com'
         owner.organization='citysdk'
         owner.domains='test'
         owner.save_changes()"

)}


function manual()
{
    cat <<-'EOF'
		1) Ensure $HOME/.rvm/bin is on your $PATH
	EOF
}


# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

all_tasks=(
    add_archlinuxfr_repo
    packages_official_install
    packages_aur_install
    rvm_install
    rvm_ruby
    rvm_gemset
    postgresql_config
    postgresql_create
    postgresql_extensions
    postgresql_user
    postgresql_data
    postgresql_import
    postgresql_schema
    postgresql_migrations
    config_init
    config_ln
    cms_set_admin_details
    manual
)

function usage()
{
    cat <<-'EOF'
		Set up a development environment

		Usage:

		    setup.sh [TASK... ]

		Tasks:

		    add_archlinuxfr_repo
		    packages_official_install
		    packages_aur_install
		    rvm_install
		    rvm_ruby
		    rvm_gemset
		    postgresql_config
		    postgresql_create
		    postgresql_extensions
		    postgresql_user
		    postgresql_data
		    postgresql_import
		    postgresql_schema
		    postgresql_migrations
		    config_init
		    config_ln
		    cms_set_admin_details
		    manual
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

