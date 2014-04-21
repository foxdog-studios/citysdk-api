#!/usr/bin/env zsh

setopt ERR_EXIT

source ${0:h}/library.zsh
unsetopt NO_UNSET


# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

db_dir=$repo/database

db_host=$(config-server db_host)
db_name=$(config-server db_name)
db_user=$(config-server db_user)
db_password=$(config-server db_pass)

dba_username=postgres

osm_dir=$repo/local/data_sets
osm_file_name=$(config-setup osm2pgsql.file_name)
osm_file_path=$osm_dir/$osm_file_name
osm_layer=osm
osm_url=$(config-setup osm2pgsql.url)


# ==============================================================================
# = Helpers                                                                    =
# ==============================================================================

function psql_dba()
{
    psql --username=$dba_username $@
}

function returns_1()
{
    tuples=$(psql_dba --command=$1 --no-align --tuples-only)
    [[ $tuples == 1 ]]
}


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function drop_database()
{
    psql_dba --echo-all <<-SQL
		\set ON_ERROR_STOP on
		DROP DATABASE IF EXISTS $db_name;
	SQL
}

function drop_role()
{
    psql_dba --echo-all <<-SQL
		\set ON_ERROR_STOP on
		DROP ROLE IF EXISTS $db_user;
	SQL
}

function create_database()
{
    local query="SELECT 1 FROM pg_database WHERE datname = '$db_name';"

    # Return if the database already exists.
    if returns_1 $query; then
        return
    fi

    psql_dba <<-SQL
		\set ON_ERROR_STOP on
		CREATE DATABASE $db_name;
	SQL
}

function create_role()
{
    local query="SELECT 1 FROM pg_roles WHERE rolname='$db_user';"

    # Return if the role already exists.
    if returns_1 $query; then
        return
    fi

    # Do not echo this comment. It'll print the user's password to the
    # terminal.
    psql_dba <<-SQL
		\set ON_ERROR_STOP on

		CREATE ROLE $db_user
		WITH
		    LOGIN
		    PASSWORD '$db_password'
		;
	SQL
}

function initialize_database()
{
    psql_dba --dbname=$db_name --file=$db_dir/initialize_database.pgsql
}

function update_osm_data()
{(
    mkdir --parent $osm_dir
    cd $osm_dir
    wget --timestamping $osm_url
)}

function import_osm_data()
{
    # Without --slim the planet_osm_rels tables is not created. This
    # table is required by create_osm_nodes.pgsql. I don't know why nor
    # do I understand the data held in that table.

    expect -f - <<-EOF
		set timeout -1
		spawn osm2pgsql                   \
		    --cache 800                   \
		    --database "$db_name"         \
		    --host "$db_host"             \
		    --hstore-all                  \
		    --latlong                     \
		    --password                    \
		    --slim                        \
		    --style $db_dir/citysdk.style \
		    --username "$dba_username"    \
		    "$osm_dir/$osm_file_name"
		expect "Password:"
		send "$db_password\r"
		expect eof
	EOF
}

function grant_permissions()
{
    psql_dba --echo-all --dbname=$db_name <<-SQL
		\set ON_ERROR_STOP on

		GRANT SELECT ON ALL TABLES IN SCHEMA public TO $db_user;
		GRANT INSERT ON ALL TABLES IN SCHEMA public TO $db_user;
		GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $db_user;
		GRANT DELETE ON ALL TABLES IN SCHEMA public TO $db_user;
		GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO $db_user;
		GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $db_user;
	SQL
}

function create_admin()
{(
    local config=$CITYSDK_CONFIG_DIR
    cd $db_dir
    bundle exec ruby create_admin.rb $config/server.json  $config/setup.json
)}

function create_required_layers()
{(
    # Requires administrative rights to reset the layer ID sequence.
    local config=$CITYSDK_CONFIG_DIR
    cd $db_dir
    bundle exec ruby $db_dir/create_required_layers.rb \
                     $config/server.json               \
                     $config/setup.json
)}

function create_osm_nodes()
{
    psql --dbname=$db_name                     \
         --file=$db_dir/create_osm_nodes.pgsql \
         --username=$db_user
}

function modify_osm_nodes()
{
    psql --dbname=$db_name                     \
         --file=$db_dir/modify_osm_nodes.pgsql \
         --username=$db_user
}

function insert_osm_import()
{
    local last_imported="$(stat -c %y $osm_file_path)"
    psql --echo-all --dbname=$db_name <<-SQL
		\set ON_ERROR_STOP on
		INSERT INTO imports (
		        layer_id,
		        last_imported,
		        status,
		        url,
		        format
		    )
		    VALUES (
		        -- 0 is the predefined ID of the OSM layer.
		        0,
		        '$last_imported'::timestamptz,
		        'Imported by the development database script.',
		        '$osm_url'::text,
		        -- It isn't really a Zip, but it's close enough.
		        'zip'::importformat
		    )
		;
	SQL
}

function update_osm_bounds()
{
    psql --echo-all --dbname=$db_name <<-'SQL'
		\set ON_ERROR_STOP on

		-- 0 is the predefined ID of the OSM layer.
		SELECT update_layer_bounds(0);
	SQL
}

function update_modalities()
{(
    local config=$CITYSDK_CONFIG_DIR/server.json
    cd $db_dir
    bundle exec ruby $db_dir/update_modalities.rb $config
)}

function ensure_turtle_prefixes()
{(
    cd $db_dir
    bundle exec ruby $db_dir/ensure_turtle_prefixes.rb \
                     "dbname=$db_name"                 \
                     "$(config-setup admin.email)"
)}

function insert_osm_properties()
{
    local src=/tmp/osm_properties.csv
    cp --force $db_dir/osm_properties.csv $src

    psql --echo-all --dbname=$db_name <<-SQL
		\set ON_ERROR_STOP on
		COPY osmprops FROM '$src' WITH CSV HEADER;
	SQL
    rm --force $src
}


# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

tasks=(
    drop_database
    drop_role
    create_database
    create_role
    initialize_database
    update_osm_data
    import_osm_data
    grant_permissions
    create_admin
    create_required_layers
    create_osm_nodes
    modify_osm_nodes
    insert_osm_import
    update_osm_bounds
    update_modalities
    ensure_turtle_prefixes
    insert_osm_properties
)

function usage()
{
    cat <<-'EOF'
		Clean and build the CitySDK database.

		Usage:

		    database.zsh [TASK... ]

		Tasks:

		    drop_database
		    drop_role
		    create_database
		    create_role
		    initialize_database
		    update_osm_data
		    import_osm_data
		    grant_permissions
		    create_admin
		    create_required_layers
		    create_osm_tuples
		    create_osm_nodes
		    modify_osm_nodes
		    insert_osm_import
		    update_osm_bounds
		    update_modalities
		    ensure_turtle_prefixes
		    insert_osm_properties
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

