# encoding: utf-8

module CitySDK

  def request_format
    # The `Accept` header takes precedence for the `:format` parameter.
    valid = ['application/json', 'text/turtle']
    accept = request.env['HTTP_ACCEPT']
    return accept if valid.include?(accept)
    case params[:format]
    when 'turtle', 'ttl' then 'text/turtle'
    else 'application/json'
    end # case
  end # def

end # module

