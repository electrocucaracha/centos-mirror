#!/bin/bash

centos7_iso=CentOS-7.0-1406-x86_64-Minimal.iso
centos7_url=http://centos.webxcreen.org/7/isos/x86_64/$centos7_iso

centos6_iso=CentOS-6.6-x86_64-minimal.iso
centos6_url=http://centos.webxcreen.org/6.6/isos/x86_64/$centos6_iso

yum install -y deltarpm
yum update -y
yum install -y git createrepo rsync httpd hardlink

systemctl enable httpd

which mrepo >/dev/null 2>&1
if [ $? -ne 0 ] ; then
    git clone https://github.com/dagwieers/mrepo.git
    cd mrepo
    make install
fi
[ -d /var/mrepo ] && mkdir -p /var/mrepo/ || :
[ -f /var/mrepo/$centos7_iso ] &&  wget --continue -P /var/mrepo/ $centos7_url || :
[ -f /var/mrepo/$centos6_iso ] &&  wget --continue -P /var/mrepo/ $centos6_url || :
sed -i "s/i386/x86_64/g" /etc/mrepo.conf
release=7.0-1406
cat << EOL > /etc/mrepo.conf.d/${centos7_iso::-4}.conf
[CentOS-$release]
name = CentOS Minimal \$release (\$arch)
metadata = repomd repoview
release = $release
metadata = yum
iso = $centos7_iso
EOL

release=6.6
cat << EOL > /etc/mrepo.conf.d/${centos6_iso::-4}.conf
[CentOS-$release]
name = CentOS Minimal \$release (\$arch)
metadata = repomd repoview
release = $release
metadata = yum
iso = $centos6_iso
EOL
mrepo -gvv
cd /var/www/mrepo
for i in *; do if [ -d $i ]; then createrepo $i; fi done
/bin/systemctl restart  httpd.service

# http://localhost:8080/mrepo/
