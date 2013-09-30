#!/usr/bin/env bash
versions=("9.1-RELEASE" "9.2-RC4" "10.0-ALPHA3")
sets=("base.txz" "kernel.txz")
locale=".fr"
baseurl="ftp://ftp${locale}.freebsd.org/pub/FreeBSD/releases/amd64/amd64"

for version in ${versions[*]}
do
    mkdir $version
    for s in ${sets[*]}
    do
        wget $baseurl/$version/$s -O $version/$s
    done
done
