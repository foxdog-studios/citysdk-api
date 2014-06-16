#!/usr/bin/env zsh

setopt ERR_EXIT
source ${0:h}/../../scripts/library.zsh

unsetopt NO_UNSET
cd $repo/devsite
setopt NO_UNSET

bundle exec rerun 'rackup --server thin --port 9296'

