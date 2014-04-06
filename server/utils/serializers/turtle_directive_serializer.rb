# encoding: utf-8

module CitySDK
  class TurtleDirectiveSerializer
    def initialize(options)
    end # def

    def serialize()
      config = lambda { |key| CONFIG.fetch(key) }
      lines = [
        create_base_directive(config.call(:ep_api_url)),
        create_prefix_directive(':', config.call(:ep_rdf_url))
      ]
      cursor = Prefix.select(:prefix, :url).order(:prefix)
      lines += cursor.map do |prefix|
        create_prefix_directive(prefix.prefix, prefix.url)
      end # do
      lines.join("\n")
    end # def

    private

    def create_base_directive(iri)
      "@base <#{ iri }> ."
    end # def

    def create_prefix_directive(label, iri)
      "@prefix #{ label } <#{ iri }> ."
    end # def
  end # class
end # module

