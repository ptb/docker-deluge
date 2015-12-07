FROM debian:jessie
# MAINTAINER Peter T Bosse II <ptb@ioutime.com>

RUN \
  REQUIRED_PACKAGES="libboost-python-dev libboost-system-dev libgeoip-dev" \
  && BUILD_PACKAGES="build-essential libffi-dev libssl-dev wget" \

  && USERID_ON_HOST=1026 \

  && useradd \
    --comment Deluge \
    --create-home \
    --gid users \
    --no-user-group \
    --shell /usr/sbin/nologin \
    --uid $USERID_ON_HOST \
    deluge \

  && echo "debconf debconf/frontend select noninteractive" \
    | debconf-set-selections \

  && sed \
    -e "s/httpredir.debian.org/debian.mirror.constant.com/" \
    -i /etc/apt/sources.list \

  && apt-get update -qq \
  && apt-get install -qqy \
    $REQUIRED_PACKAGES \
    $BUILD_PACKAGES \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/arvidn/libtorrent/releases/latest \
    | sed -n "s/^.*browser_download_url.*: \"\(.*libtorrent-rasterbar.*\.tar\.gz\)\".*/\1/p" \
    | wget \
      --input-file - \
      --output-document - \
      --quiet \
    | tar -xz -C /tmp/ \
  && mv /tmp/libtorrent-rasterbar* /tmp/libtorrent-rasterbar \
  && cd /tmp/libtorrent-rasterbar/ \
  && ./configure --enable-python-binding --with-libgeoip --with-libiconv \
  && make -j$(nproc) \
  && make install \
  && ldconfig \

  && wget \
    --output-document - \
    --quiet \
    https://bootstrap.pypa.io/ez_setup.py \
    | python \
  && wget \
    --output-document - \
    --quiet \
    https://raw.github.com/pypa/pip/master/contrib/get-pip.py \
    | python \

  && pip install chardet mako pyxdg twisted[tls] \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/deluge-torrent/deluge/tarball/1.3-stable \
    | tar -xz -C /tmp/ \
  && mv /tmp/deluge-torrent-deluge* /tmp/deluge \
  && cd /tmp/deluge/ \
  && python setup.py build \
  && python setup.py install \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/just-containers/s6-overlay/releases/latest \
    | sed -n "s/^.*browser_download_url.*: \"\(.*s6-overlay-amd64.tar.gz\)\".*/\1/p" \
    | wget \
      --input-file - \
      --output-document - \
      --quiet \
    | tar -xz -C / \

  && mkdir -p /etc/services.d/deluged/ \
  && printf "%s\n" \
    "#!/usr/bin/env sh" \
    "set -ex" \
    "exec s6-applyuidgid -g 100 -u $USERID_ON_HOST \\" \
    "  /usr/local/bin/deluged \\" \
    "  --config /home/deluge \\" \
    "  --do-not-daemonize \\" \
    "  --loglevel info" \
    > /etc/services.d/deluged/run \
  && chmod +x /etc/services.d/deluged/run \

  && mkdir -p /etc/services.d/deluge-web/ \
  && printf "%s\n" \
    "#!/usr/bin/env sh" \
    "set -ex" \
    "exec s6-applyuidgid -g 100 -u $USERID_ON_HOST \\" \
    "  /usr/local/bin/deluge-web \\" \
    "  --config /home/deluge \\" \
    "  --loglevel info" \
    > /etc/services.d/deluge-web/run \
  && chmod +x /etc/services.d/deluge-web/run \

  && apt-get purge -qqy --auto-remove \
    $BUILD_PACKAGES \
  && apt-get clean -qqy \
  && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

ENTRYPOINT ["/init"]
EXPOSE 8112 58846

# docker build --rm --tag ptb2/deluge .
# docker run --detach --name deluge --net host \
#   --publish 8112:8112/tcp \
#   --publish 58846:58846/tcp \
#   --volume /volume1/Config/Deluge:/home/deluge \
#   --volume /volume1/Media:/home/media \
#   ptb2/deluge
