#!/usr/bin/env zsh

setopt ERR_EXIT
setopt NO_UNSET

pathnames=(
    '/'
    '/nodes'
    '/nodes/'
    '/routes'
    '/routes/'
    '/regions'
    '/regions/'
    '/ptstops'
    '/ptstops/'
    '/ptlines'
    '/ptlines/'
    '/nodes/?per_page=1'
    '/nodes/?per_page=1000'
    '/nodes/?page=2'
    '/nodes/?name=Appley%20Bridge'
    '/nodes/?layer=osm'
    '/nodes/?layer=osm|gtfs'
    '/nodes/?layer=osm,gtfs'
    '/nodes/?layer=*'
    '/nodes/?osm::tourism'
    '/nodes/?osm::tourism=museum'
    '/nodes/?osm::tourism=museum&osm::tourism=zoo&data_op=or'
    '/n344370768'
    '/n344370768/select/regions'
    '/n344370768/select/routes'
    '/w4441614/select/routes?geom'
    '/n344370768/select/routes_start'
    '/w4441614/select/routes_start?geom'
    '/n344370768/select/routes_end'
    '/w40285734/select/routes_end'
    '/w40285734/select/routes_end?geom'
    '/r165410'
    '/r165410/select/nodes'
    '/r165410/select/routes'
    '/r165410/select/start_end'
    '/gtfs.stop.9400zzmaabm1/select/ptlines'
    '/gtfs.stop.9400zzmaabm1/select/schedule'
    '/gtfs.stop.9400zzmaabm1/select/now'
    '/gtfs.line.1.met2-0/select/ptstops'
    '/gtfs.line.1.met2-0/select/schedule'
)

urls=(http://localhost:9292${^pathnames})

chromium --new-window $urls

