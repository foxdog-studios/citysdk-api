from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

from collections import OrderedDict
from copy import copy
from cStringIO import StringIO
from pipes import quote
import json
import os
import posixpath as path
import subprocess

from fabric.api import (
    cd,
    env,
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


# =============================================================================
# = Configuratioin                                                            =
# =============================================================================

config_path = os.path.join(os.environ['CITYSDK_CONFIG_DIR'], 'setup.json')
with open(config_path) as config_file:
    config = json.load(config_file)

setup_config = config

env.setdefault('domain_name', config['server']['domain_name'])

if env.host is None:
    env.host = config['server']['host_name']

if env.host_string is None:
    env.host_string = '{}@{}'.format(
        config['server']['administrator']['username'],
        config['server']['host_name'],
    )

if env.password is None:
    env.password = config['server']['administrator']['password']

env.user = config['server']['administrator']['username']

# (Source directory name, sub-sub-domain name, SSL)
env.apps = [
    ('cms'    , 'cms', True),
    ('devsite', 'dev', False),
    ('rdf'    , 'rdf', False),
    ('server' , None , True),
]

env.codename = 'precise'

env.deploy_to = '/var/www'
env.setdefault('deploy_user', config['server']['deploy_user']['username'])
env.deploy_group = 'www-data'

env.setdefault(
    'deploy_key',
    os.path.expanduser(config['server']['deploy_user']['local_key_path']),
)

env.nginx_conf = '/etc/nginx'
env.nginx_log = '/var/log/nginx'

env.nginx_sites_enabled = path.join(env.nginx_conf, 'sites-enabled')
env.nginx_sites_available = path.join(env.nginx_conf, 'sites-available')

env.osm_data = 'osm.pbf'
env.osm_data_url = config['osm2pgsql']['data_url']

env.osm2pgsql_tag = '0.84.0'
env.osm2pgsql_path = 'osm2pgsql-{}'.format(env.osm2pgsql_tag)

env.passenger_user = 'www-data'
env.passenger_group = 'www-data'

env.postgis_version = '2.1'

env.ruby_gemset = 'citysdk'
env.ruby_version = '1.9.3'
env.ruby_use = '{}@{}'.format(env.ruby_version, env.ruby_gemset)

env.colorize_errors = True


def ensure(key):
    value = config['administrator'][key]
    env.setdefault('admin_{}'.format(key), value)

ensure('email')
ensure('password')
ensure('name')
ensure('organization')
ensure('domains')

env.postgres_key = 'http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
env.postgres_ppa = 'http://apt.postgresql.org/pub/repos/apt/'
env.postgres_version = '9.3'

config_path = os.path.join(os.environ['CITYSDK_CONFIG_DIR'], 'server.json')
with open(config_path) as config_file:
    config = json.load(config_file)

def ensure(env_key, config_key):
    env.setdefault(
        'postgres_{}'.format(env_key),
        config['db_{}'.format(config_key)],
    )

ensure('database', 'name')
ensure('password', 'pass')
ensure('user', 'user')


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

@task
def setup(start=1):
    def restart_nginx():
        return reload_nginx(action='restart')

    tasks = [
        #
        # Installation
        #

        # System packages
        add_repositories,               # 1
        update_package_lists,           # 2
        install_packages,               # 3
        upgrade_distribution,           # 4
        remove_unused_packages,         # 5

        # RVM
        install_rvm,                    # 6
        install_rvm_requirements,       # 7
        install_ruby,                   # 8
        create_gemset,                  # 9

        # Build osm2psql
        ensure_osm2pgsql_source,        # 10
        configure_osm2pgsql,            # 11
        compile_osm2pgsql,              # 12
        install_osm2pgsql,              # 13

        #
        # Configuration
        #

        # Database creation
        ensure_database,                # 14
        ensure_database_extensions,     # 15
        ensure_user,                    # 16

        # OSM Data
        ensure_osm_data,                # 17
        run_osm2pgsql,                  # 18
        copy_database_scripts,          # 19
        create_osm_schema,              # 20
        run_migrations,                 # 21

        # Nginx
        copy_ssl_files,
        configure_nginx,                # 22
        configure_default_nginx_server, # 23
        configure_nginx_servers,        # 24

        # Deploy user
        ensure_deploy_user,             # 25

        # Deploy directories
        write_deploy_scripts,           # 26
        make_deploy_directories,        # 27
        setup_deploy_directories,       # 28
        check_deploy_directories,       # 29

        #
        # Deploy
        #

        # Deploy
        update_gem_dependants,          # 30
        copy_config,                    # 31
        deploy,                         # 32

        # Configure CMS
        create_admin,                   # 33

        restart_nginx,                  # 34
    ]

    for task in tasks[int(start) - 1:]:
        task()


# =============================================================================
# = System packages                                                           =
# =============================================================================

@task
def add_repositories():
    # Passenger
    sudo(r'''
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
            561F9B9CAC40B2F7
    ''')
    path = '/etc/apt/sources.list.d/passenger.list'
    text = (
        'deb https://oss-binaries.phusionpassenger.com/apt/passenger '
        + 'precise main'
    )
    append(path, text, use_sudo=True)
    sudo('chmod 600 {}'.format(quote(path)))

    # PostgreSQL
    sudo('curl {} | apt-key add -'.format(quote(env.postgres_key)))
    path = '/etc/apt/sources.list.d/pgdg.list'
    text = 'deb {} {}-pgdg main'.format(
        env.postgres_ppa,
        env.codename,
    )
    append(path, text, use_sudo=True)
    sudo('chmod 600 {}'.format(quote(path)))


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

            # Nginx
            'nginx-extras',

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

            # osm2pgsql (run)
            'expect',

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
# = RVM                                                                       =
# =============================================================================

@task
def install_rvm():
    return sudo('curl --location https://get.rvm.io | bash -s stable')


@task
def install_rvm_requirements():
    return sudo('rvm requirements')


@task
def install_ruby():
    return sudo('rvm install {}'.format(quote(env.ruby_version)))


@task
def create_gemset():
    return sudo('rvm {} gemset create {}'.format(
        quote(env.ruby_version),
        quote(env.ruby_gemset),
    ))


# =============================================================================
# = Build osm2pgsql                                                           =
# =============================================================================

@task
def ensure_osm2pgsql_source():
    # If the source  has already been downloaded, there is not to do.
    already_downloaded = run(
        '[[ -d {} ]]'.format(quote(env.osm2pgsql_path)),
        warn_only=True,
    ).succeeded
    if already_downloaded:
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
# = Database                                                                  =
# =============================================================================

@task
def ensure_database():
    # If the database already exists, there is thing to do.
    template = "SELECT 1 FROM pg_database WHERE datname = '{}';"
    if '1' in psql('postgres', template.format(env.postgres_database)):
        return

    command = 'createdb {}'.format(quote(env.postgres_database))
    return sudo(command, user='postgres')


@task
def ensure_database_extensions():
    return psql(env.postgres_database, r'''
        CREATE EXTENSION IF NOT EXISTS hstore;
        CREATE EXTENSION IF NOT EXISTS pg_trgm;
        CREATE EXTENSION IF NOT EXISTS postgis;
    ''')


@task
def ensure_user():
    # If the user already exists, there is nothing to do.
    query_template = "SELECT 1 FROM pg_roles WHERE rolname='{rolname}';"
    query = query_template.format(rolname=env.postgres_user)
    if '1' in psql('postgres', query):
        return

    # Create the user
    create = psql('postgres', "CREATE USER {} WITH PASSWORD '{}';".format(
        env.postgres_user,
        env.postgres_password,
    ))

    # Give the user full control over the database
    grant = psql(
        env.postgres_database,
        'GRANT ALL ON DATABASE {} TO {};'.format(
            env.postgres_database,
            env.postgres_user,
        )
    )

    return create, grant


# =============================================================================
# = OSM data                                                                  =
# =============================================================================

@task
def ensure_osm_data():
    # If the data has already been downloaded, there is nothing to do.
    already_downloaded = run(
        '[[ -f {} ]]'.format(quote(env.osm_data)),
        warn_only=True,
    ).succeeded

    if already_downloaded:
        return

    return run('curl --location --output {} {}'.format(
        quote(env.osm_data),
        quote(env.osm_data_url),
    ))


OSM2PGSQL_EXPECT = r'''
set timeout -1
spawn osm2pgsql           \
    --cache 800           \
    --database {database} \
    --host localhost      \
    --hstore-all          \
    --latlong             \
    --password            \
    --slim                \
    --username {username} \
    {data}
expect "Password:"
send "{password}\r"
expect eof
'''[1:-1]

@task
def run_osm2pgsql():
    return run('expect -f - <<< {}'.format(
        quote(OSM2PGSQL_EXPECT.format(
            data=quote(env.osm_data),
            database=quote(env.postgres_database),
            password=quote(env.postgres_password),
            username=quote(env.postgres_user),
        )),
    ))


@task
def copy_database_scripts():
    # Copy the database script to the target machine
    put(local_path='database')

    # Install the gems required by the scripts
    with cd('database'):
        rvmsudo('bundle')


@task
def create_osm_schema():
    command = 'psql {} < {}'.format(env.postgres_database, 'osm_schema.sql')
    with cd('database'):
        return sudo(command, user='postgres')


@task
def run_migrations():
    psql(env.postgres_database,
         'GRANT ALL ON SCHEMA osm TO {}'.format(env.postgres_user))

    # Create the PostgreSQL connection string
    conn = 'postgres://{user}:{password}@localhost/{name}'.format(
        user=env.postgres_user,
        password=env.postgres_password,
        name=env.postgres_database,
    )

    def migration(*args):
        with cd('database'):
            rvmdo('bundle exec sequel -m migrations {} {}'.format(
                ' '.join(quote(arg) for arg in args),
                conn,
            ))

    migration('-M', '0')
    migration()


# =============================================================================
# = Nginx                                                                     =
# =============================================================================

@task
def copy_ssl_files():
    # Create a private directory to store the SSL files.
    dirpath = path.join(env.nginx_conf, 'ssl')
    sudo('mkdir --parents {}'.format(quote(dirpath)))
    sudo('chmod 400 {}'.format(quote(dirpath)))

    def copy_server_ssl_files(app, config_key):
        def getpath(path_key):
            return os.path.expanduser(
                setup_config['ssl'][config_key][path_key]
            )

        local_certificate = getpath('local_certificate')
        local_certificate_bundle = getpath('local_certificate_bundle')
        local_key = getpath('local_key')

        # Bundle the site's certificate and the certificate chain.
        cert = StringIO()
        with open(local_certificate) as cert_file:
            cert.write(cert_file.read())
        with open(local_certificate_bundle) as bundle_file:
            cert.write(bundle_file.read())

        # Copy the certificate bundle and key into the server.
        def put_ssl(local_path, remote_path):
            return put(
                local_path=local_path,
                remote_path=remote_path,
                mode=0400,
                use_sudo=True,
            )

        put_ssl(cert, app.ssl_crt)
        put_ssl(local_key, app.ssl_key)

    copy_server_ssl_files(env.app_server, 'api')
    copy_server_ssl_files(env.app_cms, 'cms')


NGINX_CONF_TEMPLATE = r'''
# Memcached

upstream memcached {{
    server localhost:11211 weight=5 max_fails=3 fail_timeout=3s;
    keepalive 1024;
}}


# Passenger

passenger_user {passenger_user};
passenger_group {passenger_group};


# SSL

# CBC-mode ciphers might be vulnerable to a number of attacks and to
# cipher, the BEAST attack in particular (see CVE-2011-3389), so
# prefer the RC4-SHA.
ssl_ciphers RC4:HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
'''[1:-1]

@task
def configure_nginx():
    main_nginx_config = path.join(env.nginx_conf, 'nginx.conf')

    # Uncomment the Passenger directives included with the nginx-extra
    # package.
    for directive in ['root', 'ruby']:
        regex = 'passenger_{}'.format(directive)
        uncomment(main_nginx_config, regex, use_sudo=True)

    # Write the http-scope Nginx configuration.
    return put(
        local_path=StringIO(NGINX_CONF_TEMPLATE.format(
            passenger_user=env.passenger_user,
            passenger_group=env.passenger_group,
        )),
        remote_path=path.join(env.nginx_conf, 'conf.d', 'citysdk.conf'),
        mode=0400,
        use_sudo=True,
    )


@task
def configure_default_nginx_server():
    # Remove the the nginx-full package's default server
    def join(root):
        return path.join(root, 'default')

    sudo('rm --force {} {}'.format(
        quote(join(env.nginx_sites_available)),
        quote(join(env.nginx_sites_enabled)),
    ))

    # The default server configuration
    config = StringIO('server { return 404; }')
    name = 'default'
    priority = '00'

    available = path.join(env.nginx_sites_available, name)
    enabled = path.join(
        env.nginx_sites_enabled,
        '{}-{}'.format(priority, name),
    )

    put(config, available, use_sudo=True)

    # Enable the default server
    target = path.join(
        path.relpath(env.nginx_sites_available, env.nginx_sites_enabled),
        name
    )

    ln(target, enabled, use_sudo=True)


SERVER_TEMPLATE = r'''
server {{
    listen 80;
    listen [::]80;

    server_name {server_name};
    root {root};

    access_log {access_log};
    error_log {error_log};

    passenger_enabled on;
    passenger_ruby {passenger_ruby};
}}
'''[1:-1]

SSL_SERVER_TEMPLATE = r'''
server {{
    listen 80;
    listen [::]80;

    server_name {server_name};

    return 301 https://$server_name$request_uri;
}}

server {{
    listen 443 ssl;
    server_name {server_name};
    root {root};

    access_log {access_log};
    error_log {error_log};

    ssl_certificate {ssl_certificate};
    ssl_certificate_key {ssl_certificate_key};

    passenger_enabled on;
    passenger_ruby {passenger_ruby};
}}
'''[1:-1]

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

        put(config, app.server_config, use_sudo=True)
        ln(app.server_enabled_target, app.server_enabled, use_sudo=True)


# =============================================================================
# = Deploy user                                                               =
# =============================================================================

@task
def ensure_deploy_user():
    # Create the deploy user if they don't already exists.
    if run('id {}'.format(env.deploy_user), warn_only=True).failed:
        sudo('useradd --gid {} {}'.format(
            env.deploy_group,
            env.deploy_user,
        ))

    # Set up password-less access for the deploy user
    dirpath = path.join('/home', env.deploy_user, '.ssh')
    sudo('mkdir --parent {}'.format(dirpath))
    with open(env.deploy_key) as key_file:
        key = key_file.read()
    keypath = path.join(dirpath, 'authorized_keys')
    append(keypath, key, use_sudo=True)
    sudo('chown -R {}:{} {}'.format(
        env.deploy_user,
        env.deploy_group,
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
    dirpath = path.join(env.deploy_to, '.passenger')
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
def update_gem_dependants():
    local(resolve('gem/update_dependants.zsh'))


@task
def copy_config():
    local_path = os.path.join(os.environ['CITYSDK_CONFIG_DIR'], 'server.json')
    remote_dir = path.join(env.app_server.server_root, 'shared/config')
    remote_path = path.join(remote_dir, 'config.json')
    sudo('mkdir --parents {}'.format(quote(remote_dir)))
    sudo('chown -R {}:{} {}'.format(
        quote(env.deploy_user),
        quote(env.deploy_group),
        quote(remote_dir),
    ))
    put(local_path=local_path, remote_path=remote_path, use_sudo=True)

    sudo('chown {}:{} {}'.format(
        quote(env.deploy_user),
        quote(env.deploy_group),
        quote(remote_path)),
    )

    #        Read Write Execute
    # Owner: X
    # Group: X
    # Other:
    sudo('chmod 440 {}'.format(remote_path))


@task
def deploy():
    for app in env.apps.itervalues():
        cap(app, 'deploy')


# =============================================================================
# = Configure CMS                                                             =
# =============================================================================

CREATE_ADMIN_TEMPLATE = r"""
bundle exec racksh "
    owner = Owner[0]
    owner.createPW('{password}')
    owner.name='{name}'
    owner.email='{email}'
    owner.organization='{organization}'
    owner.domains='{domains}'
    owner.save_changes()
"
"""[1:-1]

@task
def create_admin():
    with cd(env.app_server.server_current):
        return rvmsudo(
            CREATE_ADMIN_TEMPLATE.format(
                domains=env.admin_domains,
                email=env.admin_email,
                name=env.admin_name,
                organization=env.admin_organization,
                password=env.admin_password,
            ),
            user=env.deploy_user,
        )


# =============================================================================
# = Non-setup tasks                                                           =
# =============================================================================

@task
def drop_database():
    return psql('postgres', 'DROP DATABASE IF EXISTS {};'.format(
        env.postgres_database,
    ))


@task
def drop_user():
    return psql('postgres', 'DROP USER IF EXISTS {};'.format(env.postgres_user))


@task
def reload_nginx(action='reload'):
    return sudo('service nginx {}'.format(quote(action)))


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

class App(object):
    def __init__(self, name, priority=None, subdomain=None, ssl=False):
        if priority is None:
            priority = '99'

        self.name = name
        self.priority = priority
        self.subdomain = subdomain
        self.ssl = ssl

        self.server_name = server_name = '.'.join(
            part for part in [subdomain, env.domain_name] if part
        )

        self.server_root = path.join(env.deploy_to, server_name)
        self.server_current = path.join(self.server_root, 'current')
        self.server_public = path.join(self.server_current, 'public')
        self.server_config = path.join(env.nginx_sites_available, server_name)

        self.server_enabled = path.join(
            env.nginx_sites_enabled,
            '%s-%s' % (priority, server_name),
        )

        self.server_enabled_target = path.join(
            path.relpath(env.nginx_sites_available, env.nginx_sites_enabled),
            self.server_name,
        )

        def make_log_path(log_type):
            name = '%s-%s.log' % (self.server_name, log_type)
            return path.join(env.nginx_log, name)

        self.access_log = make_log_path('access')
        self.error_log = make_log_path('error')

        self.local_dir = resolve(name)
        self.local_deploy = os.path.join(self.local_dir, 'config/deploy')
        self.local_deploy_script = os.path.join(self.local_deploy,
                                                'production.rb')

        self.ssl_crt = path.join(env.nginx_conf, 'ssl', '{}.crt'.format(
            self.server_name,
        ))
        self.ssl_key = path.join(env.nginx_conf, 'ssl', '{}.key'.format(
            self.server_name,
        ))


def apt_get(apt_get_command):
    command_template = \
            'apt-get --assume-yes --no-install-recommends --quiet {}'
    return sudo(command_template.format(apt_get_command.strip()))


def cap(app, task):
    subprocess.check_call([
        os.path.expanduser('~/.rvm/bin/rvm'),
        env.ruby_use,
        'do',
        'bundle',
        'exec',
        'cap',
        'production',
        task,
    ], cwd=app.local_dir)


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


def psql(database, command, *args, **update_kwargs):
    kwargs = {'user': 'postgres'}
    kwargs.update(update_kwargs)
    return sudo(
        'psql --command={command} {database}'.format(
            command=quote(command),
            database=quote(database),
        ).strip(),
        *args,
        **kwargs
    )


def resolve(*parts):
    return os.path.abspath(os.path.join(os.path.dirname(__file__), *parts))


def rvmdo(rvmdo_command, use_sudo=False, **runner_kwargs):
    runner = sudo if use_sudo else run
    rvmdo_command = rvmdo_command.strip()
    command = 'rvm {} do {}'.format(env.ruby_use, rvmdo_command)
    return runner(command, **runner_kwargs)


def rvmsudo(rvmsudo_command, **runner_kwargs):
    return rvmdo(rvmsudo_command, use_sudo=True, **runner_kwargs)


apps = OrderedDict()
for name, subdomain, ssl in env.apps:
    app = App(name, subdomain=subdomain, ssl=ssl)
    apps[name] = app
    setattr(env, 'app_%s' % (name,), app)
env.apps = apps

