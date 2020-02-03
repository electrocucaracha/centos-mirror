#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail
set -o errexit
set -o xtrace

curl -fsSL http://bit.ly/pkgInstall | PKG="pip" bash
PKG_MANAGER=$(command -v dnf || command -v yum)
sudo -H -E "$PKG_MANAGER" -q -y install deltarpm git createrepo rsync httpd hardlink
sudo systemctl enable --now httpd
pip install lxml requests

if ! command -v mrepo; then
    pushd "$(mktemp -d)"
    git clone --depth 1 https://github.com/dagwieers/mrepo.git
    cd mrepo
    sudo make install
    popd
    sudo sed -i "s|#\!/usr/bin/python|#!$(command -v python2)|g" /usr/bin/mrepo
    sudo sed -i "s|#\!/usr/bin/python|#!$(command -v python2)|g" /usr/share/createrepo/genpkgmetadata.py
    sudo sed -i "s|#\!/usr/bin/python|#!$(command -v python2)|g" /usr/share/createrepo/worker.py
fi
mkdir -p /var/mrepo/
sudo sed -i "s/i386/x86_64/g" /etc/mrepo.conf
gpg --quiet --with-fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
gpg --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

curl -o full-mirrorlist.csv https://www.centos.org/download/full-mirrorlist.csv
grep -E "^\"US\"" full-mirrorlist.csv > us-mirrorlist.csv
awk -F '","' '($5 ~ /^http/) {print $5"7/isos/x86_64/"}' us-mirrorlist.csv > mirror_unvalidated_url.lst
while read -r url; do
    if [ "$(curl -sL -w "%{http_code}" "$url" -o /dev/null --connect-timeout 3 --max-time 5)" == "200" ]; then
        iso=$(python get_minimal_url.py "$url")
        filename="${iso##*/}"
        pushd "/var/mrepo"
        sudo curl -o "$filename" "$iso"
        sudo curl -o sha256sum.txt.asc "$url/sha256sum.txt.asc"
        gpg --verify ./sha256sum.txt.asc
        popd

        sudo tee <<EOL "/etc/mrepo.conf.d/${filename::-4}.conf"
[CentOS-7]
name = CentOS Minimal \$release (\$arch)
metadata = repomd repoview
release = 7
metadata = yum
iso = $filename
EOL
        break
    fi
done < mirror_unvalidated_url.lst

sudo mrepo -gvv
cd /var/www/mrepo
for i in *; do
    if [ -d "$i" ]; then
        sudo createrepo "$i";
    fi
done
sudo systemctl restart httpd.service

# http://localhost:8080/mrepo/
