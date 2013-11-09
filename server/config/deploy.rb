require 'bundler/capistrano'
require 'capistrano/ext/multistage'
require 'rvm/capistrano'

set :application, "citysdk-api"
set :branch, "master"
set :copy_exclude, ['config.json','tmp']
set :default_stage, "testing"
set :deploy_to, '/var/www/citysdk'
set :deploy_via, :copy
set :repository,  "."
set :scm, :none
set :stages, %w(production testing opt istb lamia)
set :use_sudo, false
set :user, 'citysdk'

default_run_options[:shell] = '/bin/bash'


# =============================================================================
# = Gem installation                                                          =
# =============================================================================

# XXX: Hack to make Blunder's Capistrano tasks see the RVM. Is there a
#      better way of doing this?
set :bundle_cmd, '/home/citysdk/.rvm/bin/rvm 1.9.3 do bundle'
set :bundle_flags, '--deployment --verbose'
set :rvm_ruby_string, '1.9.3'
before 'deploy', 'rvm:install_rvm'
before 'deploy', 'rvm:install_ruby'


# =============================================================================

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  task :finalize_update, :except => { :no_release => true } do

    run <<-CMD
      rm -rf #{latest_release}/log &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/config/config.json #{release_path} &&
      mkdir -p #{latest_release}/tmp &&
      mkdir -p #{latest_release}/public
    CMD

    top.upload("../importers/periodic", "#{shared_path}", :via => :scp, :recursive => true)

  end
end


