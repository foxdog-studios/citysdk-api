# XXX: Most for this is cut 'n' paste from server's deploy.rb. Should be
#      centralised.

require 'bundler/capistrano'
require 'capistrano/ext/multistage'

set :application, 'citysdk-rdf'
set :deploy_to, '/var/www/citysdk-rdf'
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
  # Restart Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end

  task :finalize_update, :except => { :no_release => true } do
    run <<-CMD
      rm -rf #{latest_release}/log &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log
    CMD
  end
end

