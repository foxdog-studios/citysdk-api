# -*- encoding: utf-8 -*-

# If a user is removed from the database and they sumbit a session
# cookie they obtained before they were removed, current_user is
# nil (instead of an instance GuestUser, like it should). This
# before hook detects the and invalidates the session.

module CitySDK
  class CMSApplication < Sinatra::Application
    before do
      return unless current_user.nil?
      logger.info('current_user was nil, ending session')
      session_end!
    end # do
  end # class
end # module

