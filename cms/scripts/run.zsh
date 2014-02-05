#!/usr/bin/env zsh

setopt err_exit
source ${0:h}/../../scripts/library.zsh
cd $repo/cms

bundle exec rerun 'rackup --port 9294 --server thin'

