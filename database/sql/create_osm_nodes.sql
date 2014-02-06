-- -----------------------------------------------------------------------------
-- - Preamble                                                                  -
-- -----------------------------------------------------------------------------

\set ECHO all
\set ON_ERROR_STOP on


-- -----------------------------------------------------------------------------
-- - Create OSM tuples                                                         -
-- -----------------------------------------------------------------------------

-- - Points --------------------------------------------------------------------

INSERT INTO nodes (cdk_id, name, layer_id, geom)
    SELECT
        'n' || osm_id::text,
        name,
        (SELECT id FROM layers WHERE name = 'osm'),
        way
    FROM planet_osm_point
;

INSERT INTO node_data (node_id, layer_id, data)
    SELECT
        (SELECT id FROM nodes WHERE cdk_id = 'n' || osm_id::text),
        (SELECT id FROM layers WHERE name = 'osm'),
        tags
    FROM planet_osm_point
;


-- - Lines ---------------------------------------------------------------------

INSERT INTO nodes (cdk_id, name, layer_id, geom)
    SELECT
        'w' || osm_id::text,
        name,
        (SELECT id FROM layers WHERE name = 'osm'),
        way
    FROM planet_osm_line
    WHERE osm_id > 0
;

INSERT INTO node_data (node_id, layer_id, data)
    SELECT
        (SELECT id FROM nodes WHERE cdk_id = 'w' || osm_id::text),
        (SELECT id FROM layers WHERE name = 'osm'),
        tags
    FROM planet_osm_line
    WHERE osm_id > 0
;


-- - Polygons ------------------------------------------------------------------

INSERT INTO nodes (cdk_id, name, layer_id, geom)
    SELECT
        'w' || osm_id::text,
        name,
        (SELECT id FROM layers WHERE name = 'osm'),
        way
    FROM planet_osm_polygon
    WHERE osm_id > 0
;

INSERT INTO node_data (node_id, layer_id, data)
    SELECT
        (SELECT id FROM nodes WHERE cdk_id = 'w' || osm_id::text),
        (SELECT id FROM layers WHERE name = 'osm'),
        tags
    FROM planet_osm_polygon
    WHERE osm_id > 0
;


-- - Relations -----------------------------------------------------------------

INSERT INTO nodes (cdk_id, name, layer_id)
    SELECT
        'r' || id::text,
        hstore(tags) -> 'name',
        (SELECT id FROM layers WHERE name = 'osm')
    FROM planet_osm_rels
;

INSERT INTO node_data (node_id, layer_id, data)
    SELECT
        (SELECT id FROM nodes WHERE cdk_id = 'r' || planet_osm_rels.id::text),
        (SELECT id FROM layers WHERE name = 'osm'),
        hstore(tags)
    FROM planet_osm_rels
;

-- vi: filetype=pgsql
