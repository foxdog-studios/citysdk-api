#!/usr/bin/env zsh

setopt err_exit
source ${0:h}/../../scripts/library.zsh
cd $repo/devsite

bundle exec rerun 'rackup --server thin --port 9296'

