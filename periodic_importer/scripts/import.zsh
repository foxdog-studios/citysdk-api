#!/usr/bin/env zsh

setopt ERR_EXIT

source ~/.rvm/scripts/rvm
rvm use 2.1.1@citysdk
cd -- ${0:h}/..
bundle exec ruby bin/import.rb $@

