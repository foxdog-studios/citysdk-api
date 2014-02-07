-- -----------------------------------------------------------------------------
-- - Preamble                                                                  -
-- -----------------------------------------------------------------------------

\set ECHO all
\set ON_ERROR_STOP on


-- -----------------------------------------------------------------------------
-- - Modify nodes                                                              -
-- -----------------------------------------------------------------------------

-- Find all members for all relations
UPDATE nodes
    SET members = osm_rel_members_id(rels.members)
    FROM planet_osm_rels AS rels
    WHERE nodes.cdk_id = 'r' || rels.id::text
;

-- In planet_osm_polygon, polygons that are constructed from OSM
-- relations have a negative ID Add geometry data from
-- planet_osm_polygon met id = -rel_id to node.
UPDATE nodes
    SET geom = way FROM (
        SELECT
            m.cdk_id,
            way
        FROM planet_osm_polygon p, (
            SELECT
                nodes.cdk_id,
                -substring(
                    nodes.cdk_id FROM 2 FOR length(nodes.cdk_id)
                )::integer AS id
            FROM node_data, nodes
            WHERE
                node_data.node_id = nodes.id
                AND (
                    data @> '"type"=>"boundary"'::hstore
                    OR data @> '"type"=>"multipolygon"'::hstore
                )
            ) AS m
            WHERE m.id = p.osm_id
        ) AS n
        WHERE nodes.cdk_id = n.cdk_id
;

-- Convert all OSM nodes with type=route to routes
UPDATE nodes
    SET node_type = 1
    FROM (
        SELECT DISTINCT nodes.cdk_id
        FROM node_data, nodes
        WHERE
          node_data.node_id = nodes.id
          AND data @> '"type"=>"route"'::hstore
    ) AS n
    WHERE nodes.cdk_id = n.cdk_id
;

-- Route geometies to routes.
UPDATE nodes
    SET geom = route_geometry(members)
    WHERE
        members IS NOT NULL
        AND members != '{}'
        AND node_type IN (1, 3)
        AND geom IS NULL
;

