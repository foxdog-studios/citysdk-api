require 'capistrano/ext/multistage'

set :stages, %w(production testing opt)
set :default_stage, "testing"
set :application, "CSDK_CAT"
set :repository,  "."
set :scm, :none
set :branch, "master"
set :deploy_to, "/var/www/cat.citysdk"
set :copy_exclude, ['db.json','tmp','log']
set :deploy_via, :copy
set :use_sudo, false
set :user, "citysdk"

default_run_options[:shell] = '/bin/bash'

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
      ln -s #{shared_path}/config/db.json #{release_path} &&
      mkdir -p #{latest_release}/tmp &&
      mkdir -p #{latest_release}/public
    CMD
  end
end

