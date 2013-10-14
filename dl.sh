#!/usr/bin/env bash
versions=("9.1-RELEASE" "9.2-RELEASE" "10.0-BETA1")
sets=("base.txz" "kernel.txz" "lib32.txz" "src.txz")
locale=".fr"
baseurl="http://ftp${locale}.freebsd.org/pub/FreeBSD/releases/amd64/amd64"

for version in ${versions[*]}
do
    mkdir $version
    for s in ${sets[*]}
    do
        wget $baseurl/$version/$s -c -O $version/$s
    done
done
