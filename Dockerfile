FROM python:2.7.17-slim-buster
MAINTAINER Victor Morales <electrocucaracha@gmail.com>

RUN apt-get update && \
  apt-get -y --no-install-recommends install createrepo yum wget \
  lbzip2 make lftp rsync hardlink
RUN wget http://dag.wiee.rs/home-made/mrepo/mrepo-0.8.7.tar.bz2 && \
  tar -xf mrepo-0.8.7.tar.bz2 && make -C ./mrepo-0.8.7 install

ENTRYPOINT ["/usr/bin/mrepo"]
