#!/usr/bin/env zsh

setopt err_exit
source ${0:h}/../../scripts/library.zsh

unsetopt NO_UNSET
cd $repo/cms
setopt NO_UNSET

bundle exec rerun 'rackup --port 9294 --server thin'

