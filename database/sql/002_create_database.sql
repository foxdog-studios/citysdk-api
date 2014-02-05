-- Must be executed as a superuser.


-- -----------------------------------------------------------------------------
-- - Preamble                                                                  -
-- -----------------------------------------------------------------------------

\set ECHO all
\set ON_ERROR_STOP on


-- -----------------------------------------------------------------------------
-- - Create database                                                           -
-- -----------------------------------------------------------------------------

\connect postgres
CREATE DATABASE citysdk;


-- -----------------------------------------------------------------------------
-- - Extentsions                                                               -
-- -----------------------------------------------------------------------------

\connect citysdk
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS postgis;


-- vi: filetype=pgsql
