-- -----------------------------------------------------------------------------
-- - Preamble                                                                  -
-- -----------------------------------------------------------------------------

\set ECHO all
\set ON_ERROR_STOP on
\connect citysdk citysdk


-- -----------------------------------------------------------------------------
-- - Inserts                                                                   -
-- -----------------------------------------------------------------------------

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

INSERT INTO node_types (id, name) VALUES
    (0, 'node'  ),
    (1, 'route' ),
    (2, 'ptstop'),
    (3, 'ptline')
;

INSERT INTO node_data_types (id, name) VALUES
    (0, 'layer_data'),
    (1, 'comment'   )
;

