-- -----------------------------------------------------------------------------
-- - Preamble                                                                  -
-- -----------------------------------------------------------------------------

\set ECHO all
\set ON_ERROR_STOP on


-- -----------------------------------------------------------------------------
-- - Extensions                                                                -
-- -----------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS postgis;


-- -----------------------------------------------------------------------------
-- - Users table                                                               -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    -- These columns would be created by sinatra-authentication.
    id               serial PRIMARY KEY,
    email            text UNIQUE,
    hashed_password  text,
    salt             text,
    created_at       timestamp without time zone,

    -- Interpreted by sinatra-authentication as a normal user, i.e., not
    -- an administrator.
    permission_level integer DEFAULT 0,

    -- These columns are specific to the CitySDK.
    organization     text NOT NULL,
    domains          text[] NOT NULL DEFAULT '{}'::text[]
);

-- This is the name sinatra-authentication expects.
CREATE OR REPLACE VIEW sequel_users AS SELECT * FROM users;


-- -----------------------------------------------------------------------------
-- - Layer table                                                               -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS layers (
    id            serial PRIMARY KEY,
    name          text NOT NULL UNIQUE,
    title         text,
    description   text,
    data_sources  text[] NOT NULL DEFAULT '{}'::text[],

    -- Get real-time data from memcache
    realtime      boolean NOT NULL DEFAULT FALSE,

    update_range  integer DEFAULT 0, -- seconds
    update_rate   integer DEFAULT 0, -- seconds

    -- Get data from web service if not in memcache.
    webservice    text,

    validity      tstzrange,
    owner_id      integer NOT NULL REFERENCES users (id),
    created_at    timestamptz NOT NULL DEFAULT now(),
    category      text NOT NULL,
    organization  text,
    sample_url    text,
    rdf_type_uri  text,

    CONSTRAINT layer_name_alphanumeric_with_dots CHECK (
        name SIMILAR TO
        '([A-Za-z0-9]+)|([A-Za-z0-9]+)(\.[A-Za-z0-9]+)*([A-Za-z0-9]+)'
    )
);

SELECT AddGeometryColumn('layers', 'bbox', 4326, 'GEOMETRY', 2);

ALTER TABLE layers ADD CONSTRAINT constraint_bbox_4326 CHECK (
    ST_SRID(bbox) = 4326
);


-- -----------------------------------------------------------------------------
-- - Imports table                                                             -
-- -----------------------------------------------------------------------------

CREATE TYPE texttype AS ENUM (
    'field',
    'literal'
);

CREATE TYPE importformat AS ENUM (
    'csv',
    'json',
    'kml',
    'shp',
    'zip'
);

CREATE TABLE IF NOT EXISTS imports (
    layer_id int REFERENCES layers(id) PRIMARY KEY,

    -- Perform import at most every `max_frequency` seconds.
    max_frequency int CHECK (max_frequency >= 0),

    -- The last time this import was performed.
    last_imported timestamptz,

    -- A short message about the most recent import attempt.
    status text NOT NULL DEFAULT '',

    -- The URL of the data to be imported.
    url text NOT NULL CHECK (url <> ''),

    -- The format of the data to be imported. For security, any
    -- indication of the format present in the URL or the retrieved
    -- data is ignored.
    format importformat NOT NULL,

    -- TODO: Move id_type and id_text into their own table and return
    --       this table to 3NF.

    -- If `id_type` is 'field`, `id_text` is the name of the data point
    -- data field that contains the ID of the data point. If `id_type`
    -- is `literal`, `id_tpye` is the ID to be assign to each data
    -- point. 'literal' should only be used for datasets contains one
    -- data point.
    id_type texttype NOT NULL DEFAULT 'field',
    id_text text CHECK (id_text <> ''),

    -- TODO: Move name_type and name_text into their own table and
    --       return this table to 3NF.

    -- See `id_type` and `id_text`
    name_type texttype NOT NULL DEFAULT 'field',
    name_text text CHECK (name_text <> ''),

    -- The name of the field within the imported data that stores a
    -- data point's latitude, e.g., `lat`.
    latitude_field text CHECK (latitude_field <> ''),

    -- The name of the field within the imported data that stores a
    -- data point's longitude, e.g., `lon`.
    longitude_field text CHECK (longitude_field <> '')
);


-- -----------------------------------------------------------------------------
-- - Node table                                                                -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS nodes (
    id         SERIAL PRIMARY KEY,
    cdk_id     TEXT NOT NULL UNIQUE,
    name       TEXT,
    members    BIGINT[],
    related    BIGINT[],
    layer_id   INTEGER NOT NULL REFERENCES layers(id),
    node_type  INTEGER NOT NULL DEFAULT 0,
    modalities INTEGER[],
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    geom       geometry
);

-- Additional constraints
ALTER TABLE nodes
    ADD CONSTRAINT constraint_geom_4326
    CHECK (ST_SRID(geom) = 4326)
;

ALTER TABLE nodes
    ADD CONSTRAINT constraint_geom_no_geomcoll
    CHECK (GeometryType(geom) != 'GEOMETRYCOLLECTION')
;

-- Indices
CREATE INDEX ON nodes USING btree (id);
CREATE INDEX ON nodes USING btree (cdk_id);
CREATE INDEX ON nodes USING gin (members);
CREATE INDEX ON nodes USING gin (modalities);
CREATE INDEX ON nodes USING gist (geom);
CREATE INDEX ON nodes USING btree (node_type);
CREATE INDEX ON nodes USING btree (layer_id);
CREATE INDEX ON nodes USING gist (name gist_trgm_ops);
CREATE INDEX ON nodes USING btree(lower(name));
CREATE INDEX ON nodes USING btree ((members[array_lower(members, 1)]));
CREATE INDEX ON nodes USING btree ((members[array_upper(members, 1)]));


-- -----------------------------------------------------------------------------
-- - Categories                                                                -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categories (
    id   serial PRIMARY KEY,
    name text NOT NULL UNIQUE
);

INSERT INTO categories (name) VALUES
    ('administrative'),
    ('civic'         ),
    ('commercial'    ),
    ('cultural'      ),
    ('education'     ),
    ('environment'   ),
    ('health'        ),
    ('mobility'      ),
    ('natural'       ),
    ('security'      ),
    ('tourism'       )
;

-- -----------------------------------------------------------------------------
-- - Modalities                                                                -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS modalities (
    id   serial PRIMARY KEY,
    name text NOT NULL UNIQUE
);

INSERT INTO modalities (id, name) VALUES
    (  0, 'tram'     ), -- Tram, Streetcar, Light rail
    (  1, 'subway'   ), -- Subway, Metro
    (  2, 'rail'     ), -- Rail
    (  3, 'bus'      ), -- Bus
    (  4, 'ferry'    ), -- Ferry
    (  5, 'cable_car'), -- Cable car
    (  6, 'gondola'  ), -- Gondola, Suspended cable car
    (  7, 'funicular'), -- Funicular
    (109, 'airplane '), -- Airplane
    (110, 'foot'     ), -- Foot, walking
    (111, 'bicycle'  ), -- Bicycle
    (112, 'moped'    ), -- Light motorbike, moped
    (113, 'motorbike'), -- Motorbike
    (114, 'car'      ), -- Car
    (115, 'truck'    ), -- Truck
    (116, 'horse'    ), -- Horse
    (200, 'any'      )  -- Any
;


-- -----------------------------------------------------------------------------
-- - Linked data prefixes                                                      -
-- -----------------------------------------------------------------------------

-- The 'ld' prefix stands for 'linked data'.
CREATE TABLE IF NOT EXISTS ldprefix (
    prefix   text PRIMARY KEY,
    name     text NOT NULL,
    url      text NOT NULL,
    owner_id integer NOT NULL REFERENCES users (id)
);


-- -----------------------------------------------------------------------------
-- - Linked data properties                                                    -
-- -----------------------------------------------------------------------------

-- The 'ld' prefix stands for 'linked data'.
CREATE TABLE IF NOT EXISTS ldprops (
    layer_id integer NOT NULL REFERENCES layers (id),
    key      text NOT NULL,
    type     text,
    unit     text,
    lang     text,
    eqprop   text,
    descr    text,

    PRIMARY KEY (layer_id, key)
);


-- -----------------------------------------------------------------------------
-- - Node types                                                                -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS node_types (
    id   serial PRIMARY KEY,
    name text NOT NULL
);

INSERT INTO node_types (id, name) VALUES
    (0, 'node'  ),
    (1, 'route' ),
    (2, 'ptstop'),
    (3, 'ptline')
;


-- -----------------------------------------------------------------------------
-- - Node data types                                                           -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS node_data_types (
    id   serial PRIMARY KEY,
    name text NOT NULL
);

INSERT INTO node_data_types (id, name) VALUES
    (0, 'layer_data'),
    (1, 'comment'   )
;


-- -----------------------------------------------------------------------------
-- - OpenStreetMaps linked-data properties                                     -
-- -----------------------------------------------------------------------------

-- See osm_properties.csv
CREATE TABLE IF NOT EXISTS osmprops (
    key  text NOT NULL,
    val  text,
    type text,
    uri  text,
    lang text
);


-- -----------------------------------------------------------------------------
-- - Node data table                                                           -
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS node_data (
    id             serial PRIMARY KEY,
    node_id        integer NOT NULL REFERENCES nodes (id),
    layer_id       integer NOT NULL REFERENCES layers (id),
    data           hstore,
    modalities     integer[],
    -- This column is no longer used.
    node_data_type integer NOT NULL REFERENCES node_data_types (id) DEFAULT 0,
    validity       tstzrange,
    created_at     timestamp with time zone NOT NULL DEFAULT now(),
    updated_at     timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX ON node_data USING btree (node_id);
CREATE INDEX ON node_data USING gin (data);
CREATE INDEX ON node_data USING gin (modalities);
CREATE INDEX ON node_data USING gist (validity);
CREATE INDEX ON node_data USING btree (layer_id);


-- -----------------------------------------------------------------------------
-- - Functions                                                                 -
-- -----------------------------------------------------------------------------

-- Returns index of item in array. Same as Array.index in Ruby.
CREATE OR REPLACE FUNCTION idx(anyarray, anyelement) RETURNS int AS $$
SELECT i FROM (
    SELECT generate_series(array_lower($1, 1), array_upper($1, 1))
) g(i)
WHERE $1[i] = $2
LIMIT 1;
$$ LANGUAGE sql IMMUTABLE;


-- In planet_osm_rels, members column is organised like this:
-- "{w8164451,inner,w6242601,outer}"
-- First item and every second item the first are OSM nodes,
-- other items are the nodes' role in the relation:
--   http://wiki.openstreetmap.org/wiki/Relation#Roles
--
-- osm_rel_members returns array with only OSM nodes.
CREATE OR REPLACE FUNCTION osm_rel_members(members text[]) RETURNS text[] AS $$
BEGIN
    RETURN array(
        SELECT members[i]
        FROM generate_series(
            array_lower(members, 1),
            array_upper(members, 1),
            2
        ) g(i)
    );
END
$$ LANGUAGE plpgsql IMMUTABLE;


-- Looks up the internal integer id used by the API from the nodes
-- table that matches the OSM id from the array.
CREATE OR REPLACE FUNCTION osm_rel_members_id(members text[])
    RETURNS bigint[]
AS $$
BEGIN
    RETURN array(
        SELECT id FROM nodes
        JOIN (SELECT unnest(osm_rel_members(members)) AS cdk_id) n
            USING (cdk_id)
    );
END
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION derived_geometry(_geoms geometry[])
    RETURNS geometry
AS $$
DECLARE
    _gt text;
    _collection geometry;
    _points geometry;
    _lines geometry;
    _polygons geometry;
BEGIN
    _collection := ST_Collect(_geoms);
    _points     := ST_CollectionExtract(_collection, 1);
    _lines      := ST_CollectionExtract(_collection, 2);
    _polygons   := ST_CollectionExtract(_collection, 3);

    IF ST_IsEmpty(_polygons) IS FALSE THEN
        -- Of multipolygon from separate bboxes?
        RETURN ST_SetSRID(ST_Envelope(_collection), 4326);
    ELSIF ST_IsEmpty(_lines) IS FALSE THEN
        -- lines (and maybe points)
        RETURN _lines;
    ELSE -- only points
        RETURN ST_SetSRID(ST_Union(_geoms), 4326);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION route_geometry(members bigint[])
    RETURNS geometry
AS $$
BEGIN
    RETURN derived_geometry(array_agg(geom))
        FROM nodes
        JOIN (SELECT unnest(members) AS id) i USING (id);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns internal ids from array of cdk_ids
CREATE OR REPLACE FUNCTION cdk_ids_to_internal(cdk_ids text[])
    RETURNS bigint[]
AS $$
DECLARE
    _ids bigint[];
BEGIN
    _ids = array(
        SELECT id FROM nodes
        JOIN (SELECT unnest(cdk_ids) AS cdk_id) m ON m.cdk_id = nodes.cdk_id
    );

    IF array_length(cdk_ids, 1) != array_length(_ids, 1) THEN
        FOR i IN array_lower(cdk_ids, 1) .. array_upper(cdk_ids, 1) LOOP
            IF cdk_id_to_internal(cdk_ids[i]) IS NULL THEN
              RAISE EXCEPTION 'Nonexistent cdk_id --> %', cdk_ids[i];
            END IF;
        END LOOP;
    END IF;

    RETURN _ids;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION cdk_id_to_internal(_cdk_id text)
    RETURNS bigint
AS $$
DECLARE
    _id bigint;
BEGIN
    SELECT id INTO _id
    FROM nodes
    WHERE _cdk_id = cdk_id;

    IF _id IS NULL THEN
        RAISE EXCEPTION 'Nonexistent cdk_id --> %', _cdk_id;
    END IF;

    RETURN _id;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns a GeometryCollection of all the geometries of the node's members
-- (for now, only one level deep.)
-- GeometryCollections cannot be used in ST_Contains etc...
CREATE OR REPLACE FUNCTION collect_member_geometries(members bigint[])
    RETURNS geometry
AS $$
BEGIN
    RETURN ST_Collect(geom)
        FROM nodes
        JOIN (SELECT unnest(members) AS id) i USING (id);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns all rows in nodes with node_type = 1 (route)
-- with all members contained by g
CREATE OR REPLACE FUNCTION contains_routes(_geom geometry)
    RETURNS SETOF nodes
AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM nodes
        WHERE cdk_id = ANY(
            SELECT m.cdk_id FROM (
                SELECT cdk_id, unnest(members) AS member_node_id
                FROM nodes
                WHERE
                    node_type = 1
                    -- First filter out all routes that are outside
                    -- of g's bounding box
                    -- (fast because of index on
                    -- collect_member_geometries(members))
                    AND collect_member_geometries(members) @ _geom
            ) m
            JOIN nodes n ON member_node_id = n.id
            GROUP BY m.cdk_id
            HAVING every(ST_Intersects(_geom, geom))
        );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION member_nodes(_cdk_id text)
    RETURNS SETOF nodes
AS $$
BEGIN
    RETURN QUERY
        SELECT *
        FROM nodes
        WHERE (
            id = ANY((
                SELECT members
                FROM nodes
                WHERE cdk_id = _cdk_id
            ))
        );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns all routes which have input node_id in members
CREATE OR REPLACE FUNCTION has_member(_node_id bigint)
    RETURNS SETOF nodes
AS $$
BEGIN
    RETURN QUERY
        SELECT DISTINCT nodes.*
        FROM nodes
        WHERE members @> ARRAY[_node_id];
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION get_members(_cdk_id text)
    RETURNS bigint[]
AS $$
BEGIN
    RETURN (
        SELECT members
        FROM nodes
        WHERE cdk_id = _cdk_id
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION get_start_end(_cdk_id text)
    RETURNS bigint[]
AS $$
BEGIN
    RETURN (
        SELECT
            ARRAY[members[array_lower(members, 1)],
            members[array_upper(members, 1)]]
        FROM nodes
        WHERE cdk_id = _cdk_id
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns all routes which share members with input node_id
CREATE OR REPLACE FUNCTION route_members_overlap(_node_id bigint)
    RETURNS SETOF nodes
AS $$
BEGIN
    RETURN QUERY
        SELECT DISTINCT nodes.*
        FROM nodes
        JOIN (
            SELECT unnest(members) AS id
            FROM nodes
            WHERE id = _node_id
        ) m ON members @> ARRAY[m.id];
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns all nodes with GeometryType = polygon that contain input node.
CREATE OR REPLACE FUNCTION containing_polygons(_node_id bigint)
    RETURNS SETOF nodes
AS $$
BEGIN
    RETURN QUERY
        SELECT a.*
        FROM nodes a
        JOIN nodes b ON
            b.id = _node_id
            AND ST_Contains(a.geom, b.geom)
            AND GeometryType(a.geom) IN ('POLYGON', 'MULTIPOLYGON')
        ORDER BY ST_Area(a.geom);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Returns all administrative regions (layer_id = 2) that contain input node
-- order by admn_level
CREATE OR REPLACE FUNCTION containing_admr_regions(_node_id bigint)
    RETURNS SETOF nodes
AS $$
BEGIN
    RETURN QUERY
        SELECT a.*
        FROM nodes a
        JOIN nodes b ON
            b.id = _node_id
            AND ST_Contains(a.geom, b.geom)
            AND a.layer_id = 2
        JOIN node_data nd ON
            a.id = nd.node_id
            AND nd.layer_id = 2
        ORDER BY (data -> 'admn_level')::int DESC;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION route_start(members bigint[])
    RETURNS bigint
AS $$
BEGIN
    RETURN members[array_lower(members, 1)];
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION route_end(members bigint[])
    RETURNS bigint
AS $$
BEGIN
    RETURN members[array_upper(members, 1)];
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Calculates average distance between all points of
-- geometry a and geometry b
--
-- avg_distance is asymmetrical!
CREATE OR REPLACE FUNCTION avg_distance(a geometry, b geometry)
    RETURNS double precision
AS $$
BEGIN
    RETURN (
        SELECT avg(ST_Distance((g.points).geom, b))
        FROM (SELECT ST_DumpPoints(a) AS points) AS g
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Calculates standard deviation of distances between all points of
-- geometry a and geometry b
--
-- std_dev_distance is asymmetrical!
CREATE OR REPLACE FUNCTION std_dev_distance(a geometry, b geometry)
    RETURNS double precision
AS $$
BEGIN
    RETURN (
        SELECT stddev(ST_Distance((g.points).geom, b))
        FROM (SELECT ST_DumpPoints(a) AS points) AS g
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION update_layer_bounds(_layer_id integer)
    RETURNS void
AS $$
DECLARE _ext1 geometry;
DECLARE _ext2 geometry;
BEGIN
    _ext1 := (
        SELECT ST_SetSRID(ST_Extent(geom), 4326)
            FROM nodes
            JOIN node_data ON
                nodes.id = node_data.node_id
                AND node_data.layer_id = _layer_id
    );

    _ext2 := (
        SELECT ST_SetSRID(ST_Extent(geom), 4326)
            FROM nodes
            WHERE layer_id = _layer_id
    );

    UPDATE layers
        SET bbox = ST_Envelope(ST_Collect(_ext1, _ext2))
        WHERE id = _layer_id
    ;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION keys_for_layer(layer integer)
    RETURNS text[]
AS $$
BEGIN
    RETURN array_agg(distinct k) FROM (
        SELECT skeys(data) AS k
        FROM node_data WHERE layer_id = layer
    ) AS sq;
END;
$$ LANGUAGE plpgsql;

