require 'bundler/capistrano'
require 'capistrano/ext/multistage'

set :application, "CSDKDoc"
set :copy_exclude, ['config.json', 'log', 'tmp']
set :deploy_to, "/var/www/citysdk-dev"
set :deploy_via, :copy
set :repository,  '.'
set :use_sudo, false
set :user, 'deploy'


# =============================================================================
# = Gem installation                                                          =
# =============================================================================

# XXX: Hack to make Blunder's Capistrano tasks see the RVM. Is there a
#      better way of doing this?
set :bundle_cmd, '/usr/local/rvm/bin/rvm 2.1.2@citysdk do bundle'

# Without verbose it hangs for ages without any output.
set :bundle_flags, '--deployment --verbose'


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
      ln -s #{shared_path}/config/config.json #{release_path} &&
      mkdir -p #{latest_release}/public &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log
    CMD

    # XXX: This is broken, /var/www/csdk_cms does not exist.
    run "ln -s /var/www/csdk_cms/current/utils/citysdk_api.rb #{release_path}/public/citysdk_api.rb"
  end
end


