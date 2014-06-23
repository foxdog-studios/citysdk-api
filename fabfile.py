from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

from collections import OrderedDict
from copy import copy
from cStringIO import StringIO
from pipes import quote
import json
import os
import posixpath
import re
import subprocess

from fabric.api import (
    cd,
    env,
    execute,
    hide,
    local,
    put,
    reboot,
    run,
    sudo,
    task,
    warn_only,
)

from fabric.contrib.files import (
    append,
    uncomment,
)

from fabric.contrib.project import (
    rsync_project,
)


def margin(text, strip=True):
    text = re.sub(r'^ *\|', '', text, flags=re.MULTILINE)
    if strip:
        text = text.strip()
    return text


# =============================================================================
# = Configuration                                                             =
# =============================================================================

# = Fabric ====================================================================

env.colorize_errors = True


# = External configuration ====================================================

ENV_KEY = 'CITYSDK_CONFIG_DIR'

CONFIG_DIR = os.environ[ENV_KEY]

def get_config(name, path):
    value = globals()['config_{}'.format(name)]
    for key in path.split('.'):
        value = value[key]
    return value


def load_config(name):
    file_name = posixpath.extsep.join([name, 'json'])
    config_path = os.path.join(CONFIG_DIR, file_name)
    with open(config_path) as config_file:
        return json.load(config_file)


config_server = load_config('server')
config_setup  = load_config('setup' )


# = Environment Initialisation ================================================

# Constants
env.deploy_to        = '/var/www'
env.distro_codename  = 'precise'
env.nginx_conf       = '/etc/nginx'
env.nginx_log        = '/var/log/nginx'
env.nodejs_dir       = '/opt/nodejs'
env.nodejs_bin       = '/opt/nodejs/bin/node'
env.nodejs_tag       = '0.10.29'
env.osm2pgsql_tag    = '0.84.0'
env.osm_data         = 'osm.pbf'
env.passenger_group  = 'www-data'
env.passenger_user   = 'www-data'
env.postgis_version  = '2.1'
env.postgres_key     = 'http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
env.postgres_ppa     = 'http://apt.postgresql.org/pub/repos/apt/'
env.postgres_version = '9.3'
env.ruby_gemset      = 'citysdk'
env.ruby_version     = '2.1.2'

# Applications
# (Source directory name, sub-sub-domain name, SSL)
app_templates = [
    ('cms'    , 'cms', True ),
    ('devsite', 'dev', False),
    ('rdf'    , 'rdf', False),
    ('server' , None , True ),
]

# Environment variables
env_attr_templates = [
('setup' , 'admin_domains'       , 'admin.domains'                    , False),
('setup' , 'admin_email'         , 'admin.email'                      , False),
('setup' , 'admin_name'          , 'admin.name'                       , False),
('setup' , 'admin_organization'  , 'admin.organization'               , False),
('setup' , 'admin_password'      , 'admin.password'                   , False),
('setup' , 'dba_username'        , 'database_admin.username'          , False),
('setup' , 'dba_password'        , 'database_admin.password'          , False),
('setup' , 'deploy_key'          , 'server.deploy_user.local_key_path', True ),
('setup' , 'deploy_user'         , 'server.deploy_user.username'      , False),
('setup' , 'domain_name'         , 'server.domain_name'               , False),
('setup' , 'osm_data_url'        , 'osm2pgsql.url'                    , False),
('setup' , 'osm_data_file_name'  , 'osm2pgsql.file_name'              , False),
('setup' , 'password'            , 'server.admin.password'            , False),
('server', 'postgres_database'   , 'db_name'                          , False),
('server', 'postgres_password'   , 'db_pass'                          , False),
('server', 'postgres_user'       , 'db_user'                          , False),
('setup' , 'ssl_api_local_bundle', 'ssl.api.local_certificate_bundle' , True ),
('setup' , 'ssl_api_local_crt'   , 'ssl.api.local_certificate'        , True ),
('setup' , 'ssl_api_local_key'   , 'ssl.api.local_key'                , True ),
('setup' , 'ssl_cms_local_bundle', 'ssl.cms.local_certificate_bundle' , True ),
('setup' , 'ssl_cms_local_crt'   , 'ssl.cms.local_certificate'        , True ),
('setup' , 'ssl_cms_local_key'   , 'ssl.cms.local_key'                , True ),
]

# Ensure that the environment has values for all keys.

def resolve(*parts):
    return os.path.abspath(os.path.join(os.path.dirname(__file__), *parts))

for config_name, name, path, is_path in env_attr_templates:
    if getattr(env, name, None) is None:
        value = get_config(config_name, path)
        if is_path:
            value = resolve(os.path.expanduser(value))
        env[name] = value

# Derived environmental variables
env.deploy_key            = os.path.expanduser(env.deploy_key)
env.nginx_sites_available = posixpath.join(env.nginx_conf, 'sites-available')
env.nginx_sites_enabled   = posixpath.join(env.nginx_conf, 'sites-enabled')
env.nginx_ssl             = posixpath.join(env.nginx_conf, 'ssl')
env.nodejs_path           = 'node-v{}-linux-x64'.format(env.nodejs_tag)
env.osm2pgsql_path        = 'osm2pgsql-{}'.format(env.osm2pgsql_tag)
env.ruby_use              = '@'.join([env.ruby_version, env.ruby_gemset])

if env.host_string is None:
    env.host = get_config('setup', 'server.host_name')
    env.user = get_config('setup', 'server.admin.username')
    env.host_string = '@'.join([env.user, env.host])


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

@task(default=True)
def setup(start=1, end=None):
    tasks = [
        install_bootstrap_packages,     #  1 | System packages
        add_repositories,               #  2 |
        update_package_lists,           #  3 |
        install_packages,               #  4 |
        upgrade_distribution,           #  5 |
        remove_unused_packages,         #  6 |
        download_nodejs,                #  7 | nodejs
        install_nodejs,                 #  8 |
        install_rvm,                    #  9 | RVM
        upgrade_rvm,                    # 10 |
        install_rvm_requirements,       # 11 |
        install_ruby,                   # 12 |
        create_gemset,                  # 13 |
        install_bundler,                # 14 |
        ensure_osm2pgsql_source,        # 15 | Build osm2psql
        configure_osm2pgsql,            # 16 |
        compile_osm2pgsql,              # 17 |
        install_osm2pgsql,              # 18 |
        ensure_superuser,               # 19 | Database (part 1)
        ensure_database,                # 20 |
        ensure_role,                    # 21 |
        initialize_database,            # 22 |
        download_osm_data,              # 23 | OSM (part 1)
        import_osm_data,                # 24 |
        grant_permissions,              # 25 | Database (part 2)
        setup_admin_ruby_env,           # 26 |
        ensure_citysdk_admin,           # 27 |
        create_required_layers,         # 28 |
        create_osm_nodes,               # 29 | OSM (part 2)
        modify_osm_nodes,               # 30 |
        insert_osm_import,              # 31 |
        update_osm_bounds,              # 32 |
        update_modalities,              # 33 |
        ensure_turtle_prefixes,         # 34 |
        insert_osm_properties,          # 35 |
        copy_periodic_importer,         # 36 | Periodic import
        create_periodic_import_cron,    # 37 |
        copy_ssl_files,                 # 38 | Nginx
        configure_nginx,                # 39 |
        configure_default_nginx_server, # 40 |
        configure_nginx_servers,        # 41 |
        ensure_deploy_user,             # 42 | Deploy user
        write_deploy_scripts,           # 43 | Deploy apps
        make_deploy_directories,        # 44 |
        setup_deploy_directories,       # 45 |
        check_deploy_directories,       # 46 |
        deploy_all,                     # 47 | Deploy
        copy_config,                    # 48 |
        restart_nginx,                  # 49 |
    ]

    start = int(start) - 1
    end = len(tasks) if end is None else int(end)
    selected_tasks = tasks[start:end]

    for task in selected_tasks:
        execute(task)


# =============================================================================
# = System packages                                                           =
# =============================================================================

@task
def install_bootstrap_packages():
    apt_get('install curl python-software-properties')


@task
def add_repositories():
    # Passenger
    sudo(r'''
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
            561F9B9CAC40B2F7
    ''')
    path = r'/etc/apt/sources.list.d/passenger.list'
    text = (
        r'deb https://oss-binaries.phusionpassenger.com/apt/passenger '
        r'precise main'
    )
    append(path, text, use_sudo=True)
    sudo(r'chmod 600 {}'.format(quote(path)))

    # Node.js
    add_apt_repository('ppa:chris-lea/node.js')

    # PostgreSQL
    sudo(r'curl {} | apt-key add -'.format(quote(env.postgres_key)))
    path = r'/etc/apt/sources.list.d/pgdg.list'
    text = r'deb {} {}-pgdg main'.format(env.postgres_ppa, env.distro_codename)
    append(path, text, use_sudo=True)
    sudo(r'chmod 600 {}'.format(quote(path)))


@task
def update_package_lists():
    apt_get('update')


@task
def install_packages():
    apt_get(
        'install ' + ' '.join([
            # charlock_holmes
            'libicu-dev',

            # Memcached
            'memcached',

            # Mongodb
            'mongodb',

            # Nginx
            'nginx-extras',

            # Node.js
            'make',
            'nodejs',

            #nrodimporter
            'unzip',

            # NTP
            'ntp',

            # osm2pgsql (build)
            'automake',
            'g++',
            'git',
            'libbz2-dev',
            'libgeos++-dev',
            'libpq-dev',
            'libprotobuf-c0-dev',
            'libtool',
            'libxml2-dev',
            'postgresql-server-dev-{postgres_version}',
            'proj',
            'protobuf-c-compiler',
            'zlib1g-dev',

            # Passenger
            'passenger',

            # PostGIS
            'postgresql-{postgres_version}-postgis-{postgis_version}',

            # PostgreSQL
            'postgresql-{postgres_version}',
            'postgresql-contrib-{postgres_version}',
        ]).format(
            postgis_version=env.postgis_version,
            postgres_version=env.postgres_version,
        )
    )


@task
def upgrade_distribution():
    apt_get('dist-upgrade')


@task
def remove_unused_packages():
    apt_get('autoremove')


# =============================================================================
# = nodejs                                                                    =
# =============================================================================

@task
def download_nodejs():
    if already_downloaded(env.nodejs_path):
        return

    # Download nodejs binaries
    url = 'http://nodejs.org/dist/v{0}/node-v{0}-linux-x64.tar.gz'
    return run('curl --location {} | tar xz'.format(
        quote(url.format(env.nodejs_tag)),
    ))


def already_downloaded(path):
    return run('[[ -d {} ]]'.format(quote(path)), warn_only=True).succeeded


@task
def install_nodejs():
    # remove old version
    sudo('rm -rf {dst}'.format(dst=quote(env.nodejs_dir)))
    sudo('cp -r {src} {dst}'.format(
        src=quote(env.nodejs_path),
        dst=quote(env.nodejs_dir)
    ))


# =============================================================================
# = RVM                                                                       =
# =============================================================================

RVM_BIN = '/usr/local/rvm/bin/rvm'

@task
def install_rvm():
    return sudo('curl --location https://get.rvm.io | bash -s stable')


@task
def upgrade_rvm():
    return sudo('{} get stable'.format(RVM_BIN))


@task
def install_rvm_requirements():
    return sudo('{} requirements'.format(RVM_BIN))


@task
def install_ruby():
    return sudo('{} install {}'.format(
        RVM_BIN,
        quote(env.ruby_version)
    ))


@task
def create_gemset():
    return sudo('{} {} gemset create {}'.format(
        RVM_BIN,
        quote(env.ruby_version),
        quote(env.ruby_gemset),
    ))


@task
def install_bundler():
    return rvmsudo('gem install bundler')


# =============================================================================
# = Build osm2pgsql                                                           =
# =============================================================================

@task
def ensure_osm2pgsql_source():
    # If the source  has already been downloaded, there is not to do.
    if already_downloaded(env.osm2pgsql_path):
        return

    # Download osm2pgsql source
    url = 'https://github.com/openstreetmap/osm2pgsql/archive/{}.tar.gz'
    return run('curl --location {} | tar xz'.format(
        quote(url.format(env.osm2pgsql_tag)),
    ))


OSM2PGSQL_PATCH = r'''
229c229
< CFLAGS = -g -O2
---
> CFLAGS = -O2 -march=native -fomit-frame-pointer
235c235
< CXXFLAGS = -g -O2
---
> CXXFLAGS = -O2 -march=native -fomit-frame-pointer
'''[1:-1]

@task
def configure_osm2pgsql():
    with cd(env.osm2pgsql_path):
        run('./autogen.sh')
        run('./configure')
        run('patch Makefile <<< {}'.format(quote(OSM2PGSQL_PATCH)))


@task
def compile_osm2pgsql():
    with cd(env.osm2pgsql_path):
        run('make')


@task
def install_osm2pgsql():
    with cd(env.osm2pgsql_path):
        sudo('make install')


# =============================================================================
# = Database (part 1)                                                         =
# =============================================================================

@task
def ensure_superuser():
    # Only attempt to create a superuser if does not already exists.
    psql_commands = margin(r'''
       |\set ON_ERROR_STOP on
       |SELECT 1 FROM pg_roles WHERE rolname='{role_name}';
    ''').format(role_name=env.dba_username)
    command = 'psql --no-align --tuples-only <<< {commands}'
    command = command.format(commands=quote(psql_commands))
    result = sudo(command, user='postgres')
    if result.stdout == '1':
        return

    psql_commands = margin(r'''
       |\set ON_ERROR_STOP on
       |CREATE ROLE {role} WITH
       |    LOGIN
       |    SUPERUSER
       |    PASSWORD '{password}';
    ''').format(role=env.dba_username, password=env.dba_password)
    command = 'psql --echo-hidden <<< {psql_commands}'
    command = command.format(psql_commands=quote(psql_commands))
    with hide('everything'):
        sudo(command, user='postgres')


@task
def ensure_database():
    # If the database already exists, there is thing to do.
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |SELECT 1 FROM pg_database WHERE datname = '{}';
    ''').format(env.postgres_database)
    if psql_returns_1('postgres', env.dba_username, commands):
        return

    # Create the database.
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |CREATE DATABASE {database};
    ''').format(database=env.postgres_database)
    return psql('postgres', env.dba_username, commands)


@task
def ensure_role():
    if role_exists(env.postgres_user):
        return

    # Create the user
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |CREATE ROLE {role} WITH LOGIN PASSWORD '{password}';
    ''').format(
        role=env.postgres_user,
        password=env.postgres_password,
    )
    with hide():
        return psql('postgres', env.dba_username, commands, echo_all=False)


@task
def initialize_database():
    return psql_script('initialize_database.pgsql')


# =============================================================================
# = OSM data                                                                  =
# =============================================================================

@task
def download_osm_data():
    run('wget --timestamping {url}'.format(url=quote(env.osm_data_url)))


@task
def import_osm_data():
    osm2pgsql_expect = margin(r'''
       |osm2pgsql \
       |    --cache 800 \
       |    --database {database} \
       |    --host /var/run/postgresql \
       |    --hstore-all \
       |    --latlong \
       |    --slim \
       |    --style citysdk.style \
       |    {data}
    ''')

    put(local_path='database/citysdk.style')

    return run(osm2pgsql_expect.format(
        data=quote(env.osm_data_file_name),
        database=quote(env.postgres_database),
    ))


# =============================================================================
# = Database (part 2)                                                         =
# =============================================================================

@task
def grant_permissions():
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |GRANT SELECT ON ALL TABLES IN SCHEMA public TO {role_name};
       |GRANT INSERT ON ALL TABLES IN SCHEMA public TO {role_name};
       |GRANT UPDATE ON ALL TABLES IN SCHEMA public TO {role_name};
       |GRANT DELETE ON ALL TABLES IN SCHEMA public TO {role_name};
       |GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO {role_name};
       |GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO {role_name};
    ''').format(role_name=env.postgres_user)
    return psql(env.postgres_database, env.dba_username, commands)


@task
def setup_admin_ruby_env():
    gemfile = StringIO(margin(r'''
       |source 'https://rubygems.org'
       |ruby '{ruby_version}'
       |#ruby-gemset={ruby_gemset}
       |gem 'docopt'
       |gem 'pg'
       |gem 'sequel'
       |gem 'sinatra'
       |gem 'sinatra-sequel'
       |gem 'sinatra-authentication'
    ''').format(
        ruby_gemset=env.ruby_gemset,
        ruby_version=env.ruby_version,
    ))

    gemfile_path = 'Gemfile'

    server_config = {
        'db_name': env.postgres_database,
        'db_host': 'localhost',
        'db_user': env.postgres_user,
        'db_pass': env.postgres_password,
    }

    server_config_path = 'server.json'

    setup_config = {
        'admin': {
            'email':        env.admin_email,
            'password':     env.admin_password,
            'organization': env.admin_organization,
            'domains':      env.admin_domains,
        },
        'database_admin': {
            'username': env.dba_username,
            'password': env.dba_password,
        }
    }

    setup_config_path = 'setup.json'

    def put_db(file_name):
        put(local_path=os.path.join('database', file_name))

    def put_json(obj, remote_path):
        put(
            local_path=StringIO(json.dumps(obj)),
            remote_path=remote_path,
        )
        return run('chmod 600 {}'.format(quote(remote_path)))

    put_db('create_admin.rb')
    put_db('create_required_layers.rb')
    put_db('ensure_turtle_prefixes.rb')
    put_db('update_modalities.rb')
    put_db('osm_properties.csv')
    put(local_path=gemfile, remote_path=gemfile_path)
    put_json(server_config, server_config_path)
    put_json(setup_config, setup_config_path)
    rvmsudo('bundle install')


@task
def ensure_citysdk_admin():
    return rvmdo('ruby create_admin.rb server.json setup.json')


@task
def create_required_layers():
    return rvmdo('ruby create_required_layers.rb server.json setup.json')


# =============================================================================
# = OSM (part 2)                                                              =
# =============================================================================

@task
def create_osm_nodes():
    psql_script('create_osm_nodes.pgsql')


@task
def modify_osm_nodes():
    psql_script('modify_osm_nodes.pgsql')


@task
def insert_osm_import():
    last_imported = run('stat -c %y {}'.format(env.osm_data_file_name)).stdout
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |INSERT INTO imports (
       |        layer_id,
       |        last_imported,
       |        status,
       |        url,
       |        format
       |    )
       |    VALUES (
       |        -- 0 is the predefined ID of the OSM layer.
       |        0,
       |        '{last_imported}'::timestamptz,
       |        'Imported by the development database script.',
       |        '{url}'::text,
       |        -- It isn't really a Zip, but it's close enough.
       |        'zip'::importformat
       |    )
       |;
    ''').format(
        last_imported=last_imported,
        url=env.osm_data_url,
    )
    return psql(env.postgres_database, env.dba_username, commands)


@task
def update_osm_bounds():
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |-- 0 is the predefined ID of the OSM layer.
       |SELECT update_layer_bounds(0);
    ''')
    return psql(env.postgres_database, env.dba_username, commands)


@task
def update_modalities():
    rvmdo('ruby update_modalities.rb server.json')


@task
def ensure_turtle_prefixes():
    command = "ruby ensure_turtle_prefixes.rb dbname={dbname} {admin_email}"
    command = command.format(
        dbname=quote(env.postgres_database),
        admin_email=quote(env.admin_email),
    )
    return rvmdo(command)

@task
def insert_osm_properties():
    src = 'osm_properties.csv'
    dst = posixpath.join('/tmp', src)
    run('cp {} {}'.format(src, dst))
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |COPY osmprops FROM '{}' WITH CSV HEADER;
    ''').format(dst)
    psql(env.postgres_database, env.dba_username, commands)
    run('rm --force {}'.format(dst))


# =============================================================================
# = Periodic importer                                                         =
# =============================================================================

@task
def copy_periodic_importer():
    dirname='periodic_importer'
    rsync_project(
        remote_dir=dirname,
        local_dir=resolve(dirname) + '/',
    )
    with cd(dirname):
        rvmsudo('bundle install')
    config = posixpath.join(dirname, 'config.json')
    put(env.app_server.local_config, config)
    run('chmod 400 {}'.format(config))


@task
def create_periodic_import_cron():
    script = StringIO(margin(r'''
       |#!/usr/bin/env bash
       |set -o errexit
       |cd /home/{user}/periodic_importer
       |/usr/local/rvm/bin/rvm 2.1.2@citysdk do \
       |        bundle exec                     \
       |        ruby bin/import.rb config.json  \
       |        &>> /home/{user}/import.log
    ''').format(user=env.user))
    remote_path='import.sh'
    put(local_path=script, remote_path=remote_path)
    run('chmod 700 {}'.format(quote(remote_path)))
    run('crontab <<< {}'.format(
        quote('0 * * * * /home/{}/import.sh'.format(env.user))
    ))


# =============================================================================
# = Nginx                                                                     =
# =============================================================================

@task
def copy_ssl_files():
    # Create a private directory to store the SSL files.
    sudo('mkdir --parents {}'.format(quote(env.nginx_ssl)))
    sudo('chmod 400 {}'.format(quote(env.nginx_ssl)))

    def copy_server_ssl_files(app, bundle_path, crt_path, key_path):
        # Bundle the site's certificate and the certificate chain.
        crt = StringIO()
        with open(crt_path) as crt_file:
            crt.write(crt_file.read())
        crt.write('\n')
        with open(bundle_path) as bundle_file:
            crt.write(bundle_file.read())

        # Copy the certificate bundle and key into the server.
        def put_ssl(local_path, remote_path):
            put(
                local_path=local_path,
                remote_path=remote_path,
                use_sudo=True,
            )
            sudo('chmod 400 %s' % quote(remote_path))
        put_ssl(crt, app.ssl_crt)
        put_ssl(key_path, app.ssl_key)

    copy_server_ssl_files(
        env.app_server,
        env.ssl_api_local_bundle,
        env.ssl_api_local_crt,
        env.ssl_api_local_key,
    )

    copy_server_ssl_files(
        env.app_cms,
        env.ssl_cms_local_bundle,
        env.ssl_cms_local_crt,
        env.ssl_cms_local_key,
    )


NGINX_CONF_TEMPLATE = margin(r'''
    |# Memcached
    |
    |upstream memcached {{
    |    server localhost:11211 weight=5 max_fails=3 fail_timeout=3s;
    |    keepalive 1024;
    |}}
    |
    |
    |# Passenger
    |
    |passenger_user {passenger_user};
    |passenger_group {passenger_group};
    |
    |passenger_nodejs {nodejs_bin};
    |
    |
    |# SSL
    |
    |# CBC-mode ciphers might be vulnerable to a number of attacks and to
    |# cipher, the BEAST attack in particular (see CVE-2011-3389), so
    |# prefer the RC4-SHA.
    |ssl_ciphers RC4:HIGH:!aNULL:!MD5;
    |ssl_prefer_server_ciphers on;
''')

@task
def configure_nginx():
    main_nginx_config = posixpath.join(env.nginx_conf, 'nginx.conf')

    # Uncomment the Passenger directives included with the nginx-extra
    # package.
    for directive in ['root', 'ruby']:
        regex = 'passenger_{}'.format(directive)
        uncomment(main_nginx_config, regex, use_sudo=True)

    # Write the http-scope Nginx configuration.
    remote_path = posixpath.join(env.nginx_conf, 'conf.d', 'citysdk.conf')
    put(
        local_path=StringIO(NGINX_CONF_TEMPLATE.format(
            passenger_user=env.passenger_user,
            passenger_group=env.passenger_group,
            nodejs_bin=env.nodejs_bin
        )),
        remote_path=remote_path,
        use_sudo=True,
    )
    sudo('chmod 400 %s' % quote(remote_path))


@task
def configure_default_nginx_server():
    # Remove the the nginx-full package's default server
    def join(root):
        return posixpath.join(root, 'default')

    sudo('rm --force {} {}'.format(
        quote(join(env.nginx_sites_available)),
        quote(join(env.nginx_sites_enabled)),
    ))

    # The default server configuration
    config = StringIO('server { return 404; }')
    name = 'default'
    priority = '00'

    available = posixpath.join(env.nginx_sites_available, name)
    enabled = posixpath.join(
        env.nginx_sites_enabled,
        '{}-{}'.format(priority, name),
    )

    put(config, available, use_sudo=True)

    # Enable the default server
    target = posixpath.join(
        posixpath.relpath(env.nginx_sites_available, env.nginx_sites_enabled),
        name
    )

    ln(target, enabled, use_sudo=True)


SERVER_TEMPLATE = margin(r'''
    |server {{
    |    listen 80;
    |    listen [::]80;
    |
    |    server_name {server_name};
    |    root {root};
    |
    |    access_log {access_log};
    |    error_log {error_log};
    |
    |    passenger_enabled on;
    |    passenger_ruby {passenger_ruby};
    |}}
''')


SSL_SERVER_TEMPLATE = margin(r'''
    |server {{
    |    listen 80;
    |    listen [::]80;
    |
    |    server_name {server_name};
    |
    |    return 301 https://$server_name$request_uri;
    |}}
    |
    |server {{
    |    listen 443 ssl;
    |    server_name {server_name};
    |    root {root};
    |
    |    # Allow users to datasets of any size.
    |    client_max_body_size 0;
    |
    |    access_log {access_log};
    |    error_log {error_log};
    |
    |    ssl_certificate {ssl_certificate};
    |    ssl_certificate_key {ssl_certificate_key};
    |
    |    passenger_enabled on;
    |    passenger_ruby {passenger_ruby};
    |}}
''')


@task
def configure_nginx_servers():
    stdout = rvmdo('passenger-config --ruby-command')
    passenger_ruby = stdout.split('\n')[3].split(' ')[-1].strip()

    for app in env.apps.itervalues():
        if app.ssl:
            template = SSL_SERVER_TEMPLATE
        else:
            template = SERVER_TEMPLATE

        config = StringIO(template.format(
            access_log=app.access_log,
            error_log=app.error_log,
            passenger_group=env.passenger_group,
            passenger_ruby=passenger_ruby,
            passenger_user=env.passenger_user,
            root=app.server_public,
            server_name=app.server_name,
            ssl_certificate=app.ssl_crt,
            ssl_certificate_key=app.ssl_key,
        ))

        put(config, app.site_config, use_sudo=True)
        ln(app.server_enabled_target, app.server_enabled, use_sudo=True)


# =============================================================================
# = Deploy user                                                               =
# =============================================================================

@task
def ensure_deploy_user():
    # Create the deploy user if they don't already exists.
    if run('id {}'.format(env.deploy_user), warn_only=True).failed:
        sudo('useradd --gid {} {}'.format(
            env.passenger_group,
            env.deploy_user,
        ))

    # Set up password-less access for the deploy user
    dirpath = posixpath.join('/home', env.deploy_user, '.ssh')
    sudo('mkdir --parent {}'.format(dirpath))
    with open(env.deploy_key) as key_file:
        key = key_file.read()
    keypath = posixpath.join(dirpath, 'authorized_keys')
    append(keypath, key, use_sudo=True)
    sudo('chown -R {}:{} {}'.format(
        env.deploy_user,
        env.passenger_group,
        dirpath,
    ))


# =============================================================================
# = Deploy directories                                                       =
# =============================================================================

DEPLOY_SCRIPT_TEMPLATE = r'''
set :deploy_to, '{deploy_to}'
set :user, '{user}'
server '{host}', :app, :web, :primary => true
'''[1:-1]


@task
def write_deploy_scripts():
    for app in env.apps.itervalues():
        write_deploy_script(app)


def write_deploy_script(app):
    if not os.path.exists(app.local_deploy):
        os.makedirs(app.local_deploy)

    with open(app.local_deploy_script, 'w') as script_file:
        script_file.write(DEPLOY_SCRIPT_TEMPLATE.format(
            deploy_to=app.server_root,
            host=env.host,
            user=env.deploy_user,
        ))


@task
def make_deploy_directories():
    # Ensure that the directory to which all applications will be
    # deployed exists and is owned by root.
    sudo('mkdir --parents {}'.format(quote(env.deploy_to)))
    sudo('chown root:root {}'.format(quote(env.deploy_to)))

    # Turning on the sticky bit allows the deploy user to read, write,
    # and delete items (e.g., files and directories) within the deploy
    # directories but prevents them from altering the directories
    # themselves.
    sudo('chmod +t {}'.format(quote(env.deploy_to)))

    # A directory for passenger to compile and store it's native
    # extensions.
    dirpath = posixpath.join(env.deploy_to, '.passenger')
    sudo('mkdir --parents {}'.format(quote(dirpath)))

    #        Read Write Execute
    # Owner: X    X     X
    # Group:
    # Other:
    sudo('chmod 700 {}'.format(quote(dirpath)))
    sudo('chown {}:{} {}'.format(
        quote(env.passenger_user),
        quote(env.passenger_group),
        quote(dirpath),
    ))

    # Create directories to deploy each of the apps to.
    for app in env.apps.itervalues():
        # Ensure the application's root deploy directories exists.
        sudo('mkdir --parents {}'.format(quote(app.server_root)))

        #        Read Write Execute
        # Owner: X    X     X
        # Group: X          X
        # Other:
        sudo('chmod 750 {}'.format(quote(app.server_root)))

        sudo('chown {}:{} {}'.format(
            quote(env.deploy_user),
            quote(env.passenger_group),
            quote(app.server_root),
        ))


@task
def setup_deploy_directories():
    for app in env.apps.itervalues():
        cap(app, 'deploy:setup')


@task
def check_deploy_directories():
    for app in env.apps.itervalues():
        cap(app, 'deploy:check')


# =============================================================================
# = Deploy                                                                    =
# =============================================================================

@task
def deploy_all():
    return map(deploy, env.apps.itervalues())


@task
def copy_config():
    for app in env.apps.itervalues():
        write_conf_file(app.local_config, app.server_config)


def write_conf_file(local_path, remote_path):
    remote_dir = posixpath.dirname(remote_path)
    sudo('mkdir --parents {}'.format(quote(remote_dir)))
    sudo('chown -R {}:{} {}'.format(
        quote(env.deploy_user),
        quote(env.passenger_group),
        quote(remote_dir),
    ))
    put(local_path=local_path, remote_path=remote_path, use_sudo=True)
    sudo('chown {}:{} {}'.format(
        quote(env.deploy_user),
        quote(env.passenger_group),
        quote(remote_path),
    ))

    #        Read Write Execute
    # Owner: X
    # Group: X
    # Other:
    sudo('chmod 440 {}'.format(quote(remote_path)))


# =============================================================================
# = Non-setup tasks                                                           =
# =============================================================================

@task
def deploy_api():
    return deploy(env.app_server)


@task
def deploy_cms():
    return deploy(env.app_cms)

@task
def deploy_dev():
    return deploy(env.app_devsite)


@task
def deploy_rdf():
    return deploy(env.app_rdf)

@task
def deploy_webservice():
    return deploy(env.app_webservice)


@task
def drop_database():
    command = 'DROP DATABASE IF EXISTS {};'.format(env.postgres_database)
    return psql('postgres', env.dba_username, command)


@task
def drop_role():
    sql = 'DROP ROLE IF EXISTS {};'.format(env.postgres_user)
    return psql('postgres', env.dba_username, sql)


@task
def reload_nginx():
    return sudo('service nginx reload')


@task
def restart_nginx():
    return sudo('service nginx restart')


@task
def start_nginx():
    return sudo('service nginx start')


@task
def stop_nginx():
    return sudo('service nginx stop')


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

class App(object):
    def __init__(self, name, priority=None, subdomain=None, ssl=False,
                 local_config=None, server_config=None):
        if priority is None:
            priority = '99'

        self.name = name
        self.priority = priority
        self.subdomain = subdomain
        self.ssl = ssl

        self.server_name = server_name = '.'.join(
            part for part in [subdomain, env.domain_name] if part
        )

        self.server_root = posixpath.join(env.deploy_to, server_name)
        self.server_current = posixpath.join(self.server_root, 'current')
        self.server_public = posixpath.join(self.server_current, 'public')
        self.server_shared = posixpath.join(self.server_root, 'shared')
        self.site_config = posixpath.join(
            env.nginx_sites_available,
            server_name
        )

        if server_config is None:
            server_config = 'shared/config/config.json'
        self.server_config = posixpath.join(self.server_root, server_config)

        self.server_enabled = posixpath.join(
            env.nginx_sites_enabled,
            '%s-%s' % (priority, server_name),
        )

        self.server_enabled_target = posixpath.join(
            posixpath.relpath(
                env.nginx_sites_available,
                env.nginx_sites_enabled
            ),
            self.server_name,
        )

        def make_log_path(log_type):
            name = '%s-%s.log' % (self.server_name, log_type)
            return posixpath.join(env.nginx_log, name)

        self.access_log = make_log_path('access')
        self.error_log = make_log_path('error')

        self.local_dir = resolve(name)
        self.local_deploy = os.path.join(self.local_dir, 'config/deploy')
        self.local_deploy_script = os.path.join(self.local_deploy,
                                                'production.rb')

        if local_config is None:
            local_config = 'server.json'
        self.local_config = os.path.join(CONFIG_DIR, local_config)

        self.ssl_crt = posixpath.join(env.nginx_conf, 'ssl', '{}.crt'.format(
            self.server_name,
        ))
        self.ssl_key = posixpath.join(env.nginx_conf, 'ssl', '{}.key'.format(
            self.server_name,
        ))


def apt_get(apt_get_command):
    command_template = \
            'apt-get --assume-yes --no-install-recommends --quiet {}'
    return sudo(command_template.format(apt_get_command.strip()))


def add_apt_repository(add_apt_repository_command):
    command_template = 'add-apt-repository --yes {}'
    return sudo(command_template.format(add_apt_repository_command.strip()))


def cap(app, task):
    return subprocess.check_call([
        os.path.expanduser('~/.rvm/bin/rvm'),
        env.ruby_use,
        'do',
        'bundle',
        'exec',
        'cap',
        'production',
        task,
    ], cwd=app.local_dir)


def deploy(app):
    write_deploy_script(app)
    return cap(app, 'deploy')


def groups(user=None):
    args = ['groups']
    if user is not None:
        args.append(quote(user))
    return run(' '.join(args)).split()


def ln(target, link_name, use_sudo=False):
    return (sudo if use_sudo else run)(
        'ln --force --symbolic {target} {link_name}'.format(
            target=quote(target),
            link_name=quote(link_name),
        )
    )


def psql(database, username, psql_commands, echo_all=True, psql_opts=None):
    echo_all = '--echo-all' if echo_all else ''
    if psql_opts is None:
        psql_opts = ''
    else:
        psql_opts = ' '.join(quote(opt) for opt in psql_opts)
    run_command = margin(r'''
       |psql {opts} {echo_all} {database} {username} <<< {commands}
    ''')
    return run(run_command.format(
        commands=quote(psql_commands),
        database=quote(database),
        echo_all=echo_all,
        opts=psql_opts,
        username=username,
    ).strip())


def psql_script(script):
    put(local_path=os.path.join('database', script))
    return run('psql --dbname={dbname} --file={filename}'.format(
        dbname=quote(env.postgres_database),
        filename=quote(script),
    ))


def psql_returns_1(*args, **kwargs):
    kwargs.setdefault('psql_opts', []).extend(['--no-align','--tuples-only'])
    kwargs['echo_all'] = False
    result = psql(*args, **kwargs)
    return result.stdout == '1'


def role_exists(role):
    commands = margin(r'''
       |\set ON_ERROR_STOP on
       |SELECT 1 FROM pg_roles WHERE rolname='{role}';
    ''').format(role=role)
    return psql_returns_1('postgres', env.user, commands)


def rvmdo(rvmdo_command, use_sudo=False, **runner_kwargs):
    runner = sudo if use_sudo else run
    rvmdo_command = rvmdo_command.strip()
    command = '{} {} do {}'.format(RVM_BIN, env.ruby_use, rvmdo_command)
    return runner(command, **runner_kwargs)


def rvmsudo(rvmsudo_command, **runner_kwargs):
    return rvmdo(rvmsudo_command, use_sudo=True, **runner_kwargs)


apps = OrderedDict()
for name, subdomain, ssl in app_templates:
    app = App(name, subdomain=subdomain, ssl=ssl)
    apps[name] = app
    setattr(env, 'app_%s' % (name,), app)
env.app_webservice = App('webservice', subdomain='webservice',
                         local_config='webservice.yml',
                         server_config='current/config.yml')
apps['webservice'] = env.app_webservice
env.apps = apps

