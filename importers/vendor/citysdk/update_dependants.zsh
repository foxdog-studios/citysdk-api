#!/usr/bin/env zsh

cd -- $0:h

src=.

dstdirs=(
    ../cms/vendor
    ../importers/vendor
)

for dstdir in $dstdirs; do
    mkdir --parents $dstdir
    dst=$dstdir/citysdk
    rm --force --recursive $dst
    cp --recursive $src $dst
done

