# encoding: utf-8

module CitySDK
  class TurtleEndpointSerializer
    def initialize(options)
    end # def

    def serialize(url)
      f = lambda { |key| CONFIG.fetch(key) }
      rdf_url          = f.call(:ep_rdf_url)
      code             = f.call(:ep_code)
      description      = f.call(:ep_description)
      api_url          = f.call(:ep_api_url)
      cms_url          = f.call(:ep_cms_url)
      info_url         = f.call(:ep_info_url)
      maintainer_email = f.call(:ep_maintainer_email)

      margin <<-TURTLE
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
end # module

