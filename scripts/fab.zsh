#!/usr/bin/env zsh

setopt err_exit

source ${0:h}/library.zsh
exec fab "$@"

