# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def permission_level(user)
        puts user.permission_level
        case user.permission_level
        when -1
          'admin'
        when 0
          'normal user'
        else
          '?'
        end # case
      end # def
    end # od
  end # class
end # module
