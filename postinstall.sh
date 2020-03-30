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

# Install dependencies
pkgs=""
for pkg in docker pip createrepo docker-compose fuseiso; do
    if ! command -v $pkg; then
        pkgs+=" $pkg"
    fi
done
if [ -n "$pkgs" ]; then
    curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs PKG_MGR_DEBUG=true bash
fi
sudo sed -i "s|#!/usr/bin/python|#!$(command -v python2)|g" /usr/share/createrepo/genpkgmetadata.py
sudo sed -i "s|#!/usr/bin/python|#!$(command -v python2)|g" /usr/share/createrepo/worker.py

# Configure mrepo
sudo mkdir -p /var/{www/mrepo,mrepo}
sudo mkdir -p /etc/{mrepo.conf.d,mrepo/httpd}
sudo cp ./config/mrepo.ini /etc/mrepo.conf
sudo cp ./config/httpd.conf /etc/mrepo/httpd/httpd.conf
sudo cp ./config/httpd-default.conf /etc/mrepo/httpd/httpd-default.conf
sudo cp ./html/HEADER.index.shtml /var/www/mrepo/
sudo cp ./html/README.index.shtml /var/www/mrepo/

# Fetch CentOS 7 ISO
pip install lxml requests
curl -o ~/full-mirrorlist.csv https://www.centos.org/download/full-mirrorlist.csv
grep -E "^\"US\"" ~/full-mirrorlist.csv > ~/us-mirrorlist.csv
awk -F '","' '($5 ~ /^http/) {print $5"7/isos/x86_64/"}' ~/us-mirrorlist.csv > ~/mirror_unvalidated_url.lst
gpg --quiet --with-fingerprint /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
gpg --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
while read -r url; do
    if [ "$(curl -sL -w "%{http_code}" "$url" -o /dev/null --connect-timeout 3 --max-time 5)" == "200" ]; then
        iso=$(python get_minimal_url.py "$url")
        filename="${iso##*/}"
        pushd /var/mrepo
        sudo curl -o "$filename" "$iso"
        sudo curl -o sha256sum.txt.asc "$url/sha256sum.txt.asc"
        gpg --verify ./sha256sum.txt.asc
        popd

        sudo tee <<EOL "/etc/mrepo.conf.d/${filename::-4}.conf"
[centos7]
name = CentOS Minimal \$release (\$arch)
metadata = repomd repoview
release = 7
metadata = yum
iso = $filename

epel = http://dl.fedoraproject.org/pub/epel/\${release}Server/\$arch
updates = http://mirror.centos.org/centos/\$release/updates/\$arch/Packages/
extras = http://mirror.centos.org/centos/\$release/extras/\$arch/Packages/
EOL
        break
    fi
done < ~/mirror_unvalidated_url.lst

docker_compose_cmd="sudo $(command -v docker-compose)"
if ! sudo docker images | grep -q mrepo ; then
    eval "$docker_compose_cmd build --compress --force-rm"
fi

# Copy CentOS 7 RPM key
mount_cmd=$($docker_compose_cmd run mrepo --remount | grep "Execute: exec /usr/bin/fuseiso" | sed "s/.*exec //g")
echo "$mount_cmd"
eval "sudo $mount_cmd"

pushd /var/www/mrepo/
sudo cp "$(sudo find . -name RPM-GPG-KEY-CentOS-7 -print -quit)" .
sudo createrepo .
popd

# Start mrepo and httpd services
$docker_compose_cmd up --detach --no-build

# sudo yum-config-manager --add-repo http://10.10.17.4/mrepo/
# sudo rpm --import http://10.10.17.4/mrepo/RPM-GPG-KEY-CentOS-7
