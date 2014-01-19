#encoding: utf-8

Sequel.migration do
  up do

    # Insert modalities
    self[:modalities].insert(:id =>   0, :name => 'tram')       # Tram, Streetcar, Light rail
    self[:modalities].insert(:id =>   1, :name => 'subway')    # Subway, Metro
    self[:modalities].insert(:id =>   2, :name => 'rail')      # Rail
    self[:modalities].insert(:id =>   3, :name => 'bus')       # Bus
    self[:modalities].insert(:id =>   4, :name => 'ferry')     # Ferry
    self[:modalities].insert(:id =>   5, :name => 'cable_car') # Cable car
    self[:modalities].insert(:id =>   6, :name => 'gondola')   # Gondola, Suspended cable car
    self[:modalities].insert(:id =>   7, :name => 'funicular') # Funicular
    self[:modalities].insert(:id => 109, :name => 'airplane ') # Airplane
    self[:modalities].insert(:id => 110, :name => 'foot')      # Foot, walking
    self[:modalities].insert(:id => 111, :name => 'bicycle')   # Bicycle
    self[:modalities].insert(:id => 112, :name => 'moped')     # Light motorbike, moped
    self[:modalities].insert(:id => 113, :name => 'motorbike') # Motorbike
    self[:modalities].insert(:id => 114, :name => 'car')       # Car
    self[:modalities].insert(:id => 115, :name => 'truck')     # Truck
    self[:modalities].insert(:id => 116, :name => 'horse')     # Horse
    self[:modalities].insert(:id => 200, :name => 'any')       # Any

    # Insert node types
    self[:node_types].insert(:id => 0, :name => 'node')
    self[:node_types].insert(:id => 1, :name => 'route')
    self[:node_types].insert(:id => 2, :name => 'ptstop')
    self[:node_types].insert(:id => 3, :name => 'ptline')

    self[:categories].insert(:name => 'natural')
    self[:categories].insert(:name => 'cultural')
    self[:categories].insert(:name => 'civic')
    self[:categories].insert(:name => 'tourism')
    self[:categories].insert(:name => 'mobility')
    self[:categories].insert(:name => 'administrative')
    self[:categories].insert(:name => 'environment')
    self[:categories].insert(:name => 'health')
    self[:categories].insert(:name => 'education')
    self[:categories].insert(:name => 'security')
    self[:categories].insert(:name => 'commercial')

    # Insert node_data types
    self[:node_data_types].insert([0, 'layer_data'])
    self[:node_data_types].insert([1, 'comment'])

    # Insert ontology prefixes
    self[:ldprefix].insert(:name => 'ArtsHolland', :prefix => 'ah:', :url => 'http://purl.org/artsholland/1.0#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'DC-Elements', :prefix => 'dc:', :url => 'http://purl.org/dc/elements/1.1/', :owner_id => 0)
    self[:ldprefix].insert(:name => 'DC-Terms', :prefix => 'dct:', :url => 'http://purl.org/dc/terms/', :owner_id => 0)
    self[:ldprefix].insert(:name => 'FOAF', :prefix => 'foaf:', :url => 'http://xmlns.com/foaf/0.1/', :owner_id => 0)
    self[:ldprefix].insert(:name => 'GeoNames', :prefix => 'gn:', :url => 'http://www.geonames.org/ontology#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'GeoSparql', :prefix => 'geos:', :url => 'http://www.opengis.net/ont/geosparql#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'GoodRelations', :prefix => 'gr:', :url => 'http://purl.org/goodrelations/v1#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'ICAL', :prefix => 'ical:', :url => 'http://www.w3.org/2002/12/cal/ical#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'OWL', :prefix => 'owl:', :url => 'http://www.w3.org/2002/07/owl#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'RDF', :prefix => 'rdf:', :url => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'RDF-Schema', :prefix => 'rdfs:', :url => 'http://www.w3.org/2000/01/rdf-schema#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'SKOS', :prefix => 'skos:', :url => 'http://www.w3.org/2004/02/skos/core#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'Time', :prefix => 'time:', :url => 'http://www.w3.org/2006/time#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'XML', :prefix => 'xml:', :url => 'http://www.w3.org/XML/1998/namespace', :owner_id => 0)
    self[:ldprefix].insert(:name => 'XSD', :prefix => 'xsd:', :url => 'http://www.w3.org/2001/XMLSchema#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'QUDT', :prefix => 'qudt:', :url => 'http://data.nasa.gov/qudt/owl/qudt#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'Unit', :prefix => 'unit:', :url => 'http://qudt.org/vocab/unit#', :owner_id => 0)
    self[:ldprefix].insert(:name => 'LinkedGeoData', :prefix => 'lgdo:', :url => 'http://linkedgeodata.org/ontology/', :owner_id => 0)
    self[:ldprefix].insert(:name => 'CitySDK', :prefix => 'csdk:', :url => 'http://purl.org/citysdk/1.0/', :owner_id => 0)



    # Insert default layers
    # TODO: categories for default layers!!

    self[:layers].insert(
      :id => 0,
      :name => 'osm',
      :organization=> 'CitySDK',
      :category => 'base.geography',
      :title => 'OpenStreetMap',
      :description => 'Base geograpy layer.',
      :data_sources => '{"Data from OpenstreetMap; openstreetmap.org © OpenStreetMap contributors"}'
      #:validity =>
      #:categories =>
    )

    self[:layers].insert(
      :id => 1,
      :name => 'gtfs',
      :organization=> 'CitySDK',
      :category => 'mobility.public_transport',
      :title => 'Public transport',
      :description => 'Layer representing GTFS public transport information.',
      :data_sources => '{"OpenOV/GOVI import through gtfs.ovapi.nl"}'
      #:validity =>
      #:categories =>
    )

    self[:layers].insert(
      :id => 2,
      :name => 'admr',
      :organization=> 'CitySDK',
      :category => 'administrative.regions',
      :title => 'Administrative borders',
      :description => 'Administrative borders.',
      :data_sources => '{"Bron: © 2012, Centraal Bureau voor de Statistiek / Kadaster, Zwolle, 2012"}'
      #:validity =>
      #:categories =>
    )

    # Insert default owners
    self[:owners].insert(:id => 0, :name => 'CitySDK', :organization => 'Waag Society', :domains => 'test', :email => 'citysdk@waag.org')
    # self[:owners].insert([1,'tom','tom@waag.org'])
    # self[:owners].insert([2,'bert','bert@waag.org'])
  end

  down do
    DB[:modalities].truncate
    DB[:node_types].truncate
    DB[:categories].truncate
    DB[:node_data_types].truncate
    DB[:ldprefix].truncate
    DB[:layers].truncate
    DB[:owners].truncate
  end

end
