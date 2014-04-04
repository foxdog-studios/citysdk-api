class CitySDKAPI < Sinatra::Application
  get '/' do
    request_format = params.fetch(:request_format)
    puts request_format, params
    case request_format
    when 'application/json' then make_json_status
    when 'text/turtle'      then make_turtle_status
    else fail "Unknown request format #{ request_format.inspect }."
    end # case
  end # do

  private

  def make_json_status
    {
      name: 'CitySDK API',
      url: request.url,
      status: 'success'
    }.to_json
  end # def

  def make_turtle_status
    f = lambda { |key| CONFIG.fetch(key) }
    rdf_url          = f.call(:ep_rdf_url)
    code             = f.call(:ep_code)
    description      = f.call(:ep_description)
    api_url          = f.call(:ep_api_url)
    cms_url          = f.call(:ep_cms_url)
    info_url         = f.call(:ep_info_url)
    maintainer_email = f.call(:ep_maintainer_email)

    border <<-TURTLE
      |@base <#{ rdf_url }#{ code }/> .
      |@prefix : <#{ rdf_url }> .
      |@prefix foaf: <http://xmlns.com/foaf/0.1/> .
      |@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
      |
      |_:ep
      |a :CitysdkEndpoint ;
      |   rdfs:description "#{ description }" ;
      |   :endpointCode "#{ code }" ;
      |   :apiUrl "#{ api_url }" ;
      |   :cmsUrl "#{ cms_url }" ;
      |   :infoUrl "#{ info_url}" ;
      |   foaf:mbox "#{ maintainer_email }" .
    TURTLE
  end # def

end # class

