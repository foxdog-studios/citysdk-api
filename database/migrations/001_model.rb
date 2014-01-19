Sequel.migration do

  up do

    $stderr.puts("Creating tables...")

    # TODO: rename node_type to node_type_id
    create_table! :nodes do
      column :id, 'serial', :primary_key => true
      String :cdk_id, :null => false
      String :name
      column :members, 'bigint[]'
      column :related, 'bigint[]'
      integer :layer_id, :null => false
      integer :node_type, :null => false , :default => 0
      column :modalities, 'integer[]'
      timestamptz :created_at, :null => false, :default => :now.sql_function
      timestamptz :updated_at, :null => false, :default => :now.sql_function
      column :geom, 'geometry'
    end

    create_table! :ldprefix do
      String :name, :null => false
      String :prefix, :null => false
      String :url, :null => false
      integer :owner_id, :null => false
    end
    run <<-SQL
      ALTER TABLE ldprefix ADD CONSTRAINT constraint_prefix_unique UNIQUE(prefix);
    SQL

    create_table! :ldprops do
      integer :layer_id, :null => false
      String :key, :null => false
      String :type
      String :unit
      String :lang
      String :eqprop
      String :descr
    end

    create_table! :node_types do
      column :id, 'serial', :primary_key => true
      String :name, :null => false
    end

    create_table! :modalities do
      column :id, 'serial', :primary_key => true
      String :name, :null => false
    end

    create_table! :categories do
      column :id, 'serial', :primary_key => true
      String :name, :null => false
    end

    create_table! :node_data do
      column :id, 'serial', :primary_key => true
      bigint :node_id, :null => false
      integer :layer_id, :null => false
      column :data, 'hstore'
      column :modalities, 'integer[]'
      integer :node_data_type, :null => false, :default => 0
      column :validity, 'tstzrange', :default => nil
      timestamptz :created_at, :null => false, :default => :now.sql_function
      timestamptz :updated_at, :null => false, :default => :now.sql_function
    end

    create_table! :node_data_types do
      column :id, 'serial', :primary_key => true
      String :name, :null => false
    end

    create_table! :owners do
      column :id, 'serial', :primary_key => true
      String :name, :null => false
      String :email, :null => false
      String :www
      String :auth_key
      String :organization
      String :domains
      String :salt
      String :passwd
      String :session
      DateTime :timeout
      timestamptz :created_at, :null => false, :default => :now.sql_function
    end

    create_table! :layers do
      column :id, 'serial', :primary_key => true
      String :name, :null => false
      String :title
      String :description
      column :data_sources, 'text[]'
      Boolean :realtime, :default => false # get real-time data from memcache
      integer :update_rate, :default => 0 # in seconds..
      String :webservice # get data from web service if not in memcache
      column :validity, 'tstzrange'
      integer :owner_id, :null => false, :default => 0
      timestamptz :imported_at, :default => nil
      timestamptz :created_at, :null => false, :default => :now.sql_function
      String :category
      String :organization

      String :import_url
      String :import_period
      String :import_status
      String :import_config

      String :sample_url

      String :rdf_type_uri

    end

    run <<-SQL
      SELECT AddGeometryColumn('layers', 'bbox', 4326, 'GEOMETRY', 2 );

      ALTER TABLE layers ADD CONSTRAINT constraint_layer_name_unique UNIQUE(name);

      ALTER TABLE layers ADD CONSTRAINT constraint_layer_name_alphanumeric_with_dots
        CHECK (name SIMILAR TO '([A-Za-z0-9]+)|([A-Za-z0-9]+)(\.[A-Za-z0-9]+)*([A-Za-z0-9]+)');

      ALTER TABLE layers ADD CONSTRAINT constraint_bbox_4326 CHECK (ST_SRID(bbox) = 4326);
    SQL

  end

  down do
    drop_table?(:nodes, :cascade=>true)
    drop_table?(:ldprefix, :cascade=>true)
    drop_table?(:ldprops, :cascade=>true)
    drop_table?(:node_types, :cascade=>true)
    drop_table?(:modalities, :cascade=>true)
    drop_table?(:categories, :cascade=>true)
    drop_table?(:node_data, :cascade=>true)
    drop_table?(:node_data_types, :cascade=>true)
    drop_table?(:owners, :cascade=>true)
    drop_table?(:layers, :cascade=>true)
  end
end
