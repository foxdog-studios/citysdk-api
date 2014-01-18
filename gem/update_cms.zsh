#!/usr/bin/env zsh

cd -- $0:h

src=.
dst=../cms/vendor/citysdk

rm --force --recursive $dst
cp --recursive $src $dst

