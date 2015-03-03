#!/bin/bash

centos_iso=CentOS-7.0-1406-x86_64-DVD.iso
centos_url=http://centos.webxcreen.org/7.0.1406/isos/x86_64/$centos_iso

sed -i "s/10.0.2.3/8.8.8.8/g" /etc/resolv.conf

yum update -y
yum install -y git createrepo rsync httpd

systemctl start httpd
systemctl enable httpd

git clone https://github.com/dagwieers/mrepo.git
cd mrepo
make install
mkdir -p /var/mrepo/centos7-x86_64
wget -P /var/mrepo/centos7-x86_64 $centos_url
sed -i "s/i386/x86_64/g" /etc/mrepo.conf
cat << EOL > /etc/mrepo.conf.d/centos7-x86_64.conf
[CentOS]
name = CentOS \$release (\$arch)
release = 1
metadata = yum
iso = $centos_iso
updates = rsync://rsync.dist1.org/pub/dist/\$release/\$arch/\$repo/
EOL
mrepo -gvv

# http://localhost:8080/mrepo/
