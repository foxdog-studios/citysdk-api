require 'bundler/capistrano'
require 'capistrano/ext/multistage'

set :application, 'citysdk-api'
set :copy_exclude, ['config.json', 'log', 'tmp']
set :deploy_via, :copy
set :repository,  '.'
set :use_sudo, false


# =============================================================================
# = Gem installation                                                          =
# =============================================================================

# XXX: Hack to make Blunder's Capistrano tasks see the RVM. Is there a
#      better way of doing this?
set :bundle_cmd, '/usr/local/rvm/bin/rvm 1.9.3@citysdk do bundle'

# Without verbose it hangs for ages without any output.
set :bundle_flags, '--deployment --verbose'


# =============================================================================

namespace :deploy do
  # Restart Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end

  task :finalize_update, :except => { :no_release => true } do
    run <<-CMD
      rm -rf #{latest_release}/log &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/config/config.json #{release_path} &&
      mkdir -p #{latest_release}/tmp &&
      mkdir -p #{latest_release}/public
    CMD

    top.upload(
      '../importers/periodic',
      shared_path,
      :via => :scp,
      :recursive => true,
    )
  end
end

