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
)

urls=(http://localhost:9292${^pathnames})

chromium --new-window $urls

