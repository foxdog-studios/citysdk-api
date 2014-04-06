# encoding: utf-8

module CitySDK
  class TurtleOSMPropertySerializer
    def initialize(options)
    end # def

    def serialize(key, value)
      predicate_object = try_find_predicate_object_from_database(key, value)

      if predicate_object.nil?
        subproperty_subject = create_subproperty_subject(key)
        # TODO: Get this into the output some how.
        subproperty_triple = create_subproperty_triple(subproperty_subject)
        predicate = subproperty_subject
        object = %{"#{ value }"}
      else
        predicate, object = predicate_object
      end # else

      "  #{ predicate } #{ object }"
    end # def

    private

    def try_find_predicate_object_from_database(key, value)
      attempts = [
        lambda { attempt_1(key, value) },
        lambda { attempt_2(key, value) },
        lambda { attempt_3(key, value) },
        lambda { attempt_4(key)        },
        lambda { attempt_5(key, value) }
      ]

      attempts.each do |attempt|
        predicate_object = attempt.call()
        unless predicate_object.nil?
          return predicate_object
        end # unless
      end # do

      nil
    end # def

    def attempt_1(key, value)
      osm_property = OSMProps
          .select(:type, :uri)
          .where(key: key, val: value)
          .first()
      return if osm_property.nil?

      type = osm_property.type
      uri = osm_property.uri
      [ type, uri ]
    end # def

    def attempt_2(key, value)
      osm_property = OSMProps
          .select(:lang, :uri)
          .where(key: key)
          .exclude(lang: nil)
          .first()
      return if osm_property.nil?

      lang = osm_property.lang
      uri = osm_property.uri
      object = %{"#{ value }"@#{ lang }}
      [ uri,  object ]
    end # def

    def attempt_3(key, value)
      osm_property = OSMProps
          .select(:uri)
          .where(key: key, type: 'string')
          .exclude(uri: nil)
          .first()
      return if osm_property.nil?

      uri = osm_property.uri
      object = %{"#{ value }"}
      [ uri, object ]
    end # def

    def attempt_4(key)
      osm_property = OSMProps
          .select(:uri)
          .where(key: key, type: 'a')
          .exclude(uri: nil)
          .first()
      return if osm_property.nil?
      [ 'a',  osm_property.type ]
    end # def

    def attempt_5(key, value)
      osm_property = OSMProps
          .select(:type, :uri)
          .where(key: key)
          .exclude(type: nil)
          .first()
      return if osm_property.nil?

      type = osm_property.type
      uri = osm_property.uri
      object = %{"#{ value }"^^xsd:#{ type }}
      [ uri,  object ]
    end # def

    def create_subproperty_subject(key)
      "<osm/#{ key }>"
    end # def

    def create_subproperty_triple(subject)
      "#{ subject } rdfs:subPropertyOf :layerProperty ."
    end # def
  end # class
end # module

