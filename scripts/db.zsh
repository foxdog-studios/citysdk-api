#!/usr/bin/env zsh

setopt ERR_EXIT
setopt NO_UNSET

source ${0:h}/library.zsh


# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

db_host=$(config-server db_host)
db_name=$(config-server db_name)
db_user=$(config-server db_user)
db_password=$(config-server db_pass)

data_path=$repo/local/data_sets/osm.pbf
data_url=$(config-setup osm2pgsql.data_url)


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function delete_db()
{
    psql "DROP DATABASE IF EXISTS $db_name;" postgres
}

function delete_user()
{
    psql "DROP USER IF EXISTS $db_user;" postgres
}

function create_db()
{
    local query="SELECT 1 FROM pg_database WHERE datname = '$db_name';"

    # Return is the database already exists
    if psql $query postgres | grep --quiet 1; then
        return
    fi

    pdo createdb $db_name
}

function create_extensions()
{
    psql 'CREATE EXTENSION IF NOT EXISTS hstore;
          CREATE EXTENSION IF NOT EXISTS pg_trgm;
          CREATE EXTENSION IF NOT EXISTS postgis;'
}

function create_user()
{
    local query="SELECT 1 FROM pg_roles WHERE rolname='$db_user';"

    # Stop this the user already exists
    if psql $query postgres | grep --quiet 1; then
        return
    fi

    psql "CREATE USER $db_user PASSWORD '$db_password'" postgres
    psql "GRANT ALL ON DATABASE $db_name TO $db_user"
}

function download_data()
{
    mkdir --parent $data_path:h

    if [[ ! -f $data_path ]]; then
        curl --location --output $data_path $data_url
    fi
}

function import_data()
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

function create_schema()
{
    # TODO: Instead of always succeeding, make the script idempotent.
    pdo psql "$db_name" < $repo/server/db/osm_schema.sql || true
}

function migrations()
{
    psql "GRANT ALL ON SCHEMA osm TO $db_user;"

    function migration()
    {(
        cd $repo/server/db
        bundle exec ./run_migrations.rb $@
    )}

    # '0' resets something
    migration 0
    migration

    unfunction migration
}

function set_admin_details()
{(
    cd $repo/server
    bundle exec racksh "
        owner = Owner[0]
        owner.createPW('$(config-setup administrator.password)')
        owner.name='$(config-setup administrator.name)'
        owner.email='$(config-setup administrator.email)'
        owner.organization='$(config-setup administrator.organization)'
        owner.domains='$(config-setup administrator.domains)'
        owner.save_changes()
    "
)}


# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

tasks=(
    delete_db
    delete_user
    create_db
    create_extensions
    create_user
    download_data
    import_data
    create_schema
    migrations
    set_admin_details
)

function usage()
{
    cat <<-'EOF'
		Clean and build the CitySDK database

		Usage:

		    db [TASK... ]

		Tasks:

		    delete_db
		    delete_user
		    create_db
		    create_extensions
		    create_user
		    download_data
		    import_data
		    create_schema
		    migrations
		    set_admin_details
	EOF
    exit 1
}

for task in $@; do
    if [[ ${tasks[(i)$task]} -gt ${#tasks} ]]; then
        usage
    fi
done

for task in ${@:-${tasks[@]}}; do
    print -P -- "%F{green}Task: $task%f"
    $task
done

