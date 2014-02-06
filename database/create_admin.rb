#!/usr/bin/env ruby

require 'json'
require 'docopt'


# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

DOCOPT = <<DOCOPT
  Create an admin user from configurations files.

  Usage:
    create_admin.rb SERVER_CONFIG SETUP_CONFIG

DOCOPT

ARGS = Docopt::docopt(DOCOPT)

SERVER_CONFIG_PATH = ARGS.fetch('SERVER_CONFIG')
SETUP_CONFIG_PATH = ARGS.fetch('SETUP_CONFIG')

def load_config(config_path)
  open(config_path) do |config_file|
    JSON.load(config_file)
  end # do
end # def

SERVER_CONFIG = load_config(SERVER_CONFIG_PATH)
SETUP_CONFIG = load_config(SETUP_CONFIG_PATH)
ADMIN_CONFIG = SETUP_CONFIG.fetch('admin')

def get_admin(key)
  ADMIN_CONFIG.fetch(key.to_s)
end # def

ADMIN_EMAIL = get_admin(:email)
ADMIN_PASSWORD = get_admin(:password)
ADMIN_DOMAINS = get_admin(:domains).split(',')

def get_db(key)
  SERVER_CONFIG.fetch("db_#{ key.to_s }")
end # def

DB_NAME = get_db(:name)
DB_HOST = get_db(:host)
DB_USER = get_db(:user)
DB_PASSWORD = get_db(:pass)

# ==============================================================================
# = Database connection                                                        =
# ==============================================================================

print 'Connecting to database...'

require 'sequel'

DB = Sequel.postgres(
  host:     DB_HOST,
  dbname:   DB_NAME,
  user:     DB_USER,
  password: DB_PASSWORD
)

DB.extension(:pg_array)

puts 'done'


# ==============================================================================
# = Create admin user                                                          =
# ==============================================================================

print 'Creating or updating admin user...'

require 'sinatra-authentication'

USER = User.set(
  email:                 ADMIN_EMAIL,
  password:              ADMIN_PASSWORD,
  password_confirmation: ADMIN_PASSWORD,
  # Admin permission level
  permission_level:      -1,
  domains:               Sequel.pg_array(ADMIN_DOMAINS)
)

puts 'done'
puts 'All done, goodbye!'

