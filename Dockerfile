FROM debian:latest

ARG TARGETPLATFORM

# 必要なパッケージをインストール
RUN apt-get update && apt-get install -y \
    wget build-essential bison flex libncurses-dev gzip nkf groff git autogen autoconf automake \
    libsqlite3-dev sqlite3 xinetd telnetd-ssl bsdmainutils

# NetHackのダウンロードと設定
RUN wget https://www.nethack.org/download/3.6.7/nethack-367-src.tgz && \
    tar zxvf nethack-367-src.tgz && \
    cd NetHack-3.6.7/include && \
    sed -i 's|#define ENTRYMAX 100|#define ENTRYMAX 1000|' config.h && \
    cd ../sys/unix && \
    sed -i -e 's|PREFIX=$(wildcard ~)/nh/install|PREFIX=|' -e 's|HACKDIR=$(PREFIX)/games/lib/$(GAME)dir|HACKDIR=$(PREFIX)/nh367|' -e 's|SHELLDIR = $(PREFIX)/games|#SHELLDIR = $(PREFIX)/games|' hints/linux && \
    sh setup.sh hints/linux && \
    cd ../../ && \
    make -B all && \
    make install

# dgamelaunchのセットアップ

RUN PLATFORM=$( \
      case ${TARGETPLATFORM} in \
        linux/amd64 ) echo "x86_64";; \
        linux/arm64 ) echo "aarch64";; \
      esac \
    ) && \
    cd / && \
    git clone https://github.com/paxed/dgamelaunch.git && \
    cd dgamelaunch && \
    sed -i '1i #define _XOPEN_SOURCE_EXTENDED 1' ee.c && \
    ./autogen.sh --enable-sqlite --enable-shmem --with-config-file=/home/nethack/etc/dgamelaunch.conf && \
    make -B && \
    sed -i -e 's|CHROOT="/opt/nethack/nethack.alt.org/"|CHROOT="/home/nethack/"|' -e 's|NHSUBDIR="/nh343/"|NHSUBDIR="/nh367/"|' -e 's|NH_VAR_PLAYGROUND="/nh343/var/"|NH_VAR_PLAYGROUND="/nh367/var/"|' -e 's|#NH_PLAYGROUND_FIXED="/home/paxed/hacking/coding/nethacksource/nethack-3.4.3-nao/nh343/"|NH_PLAYGROUND_FIXED="/home/nethack-compiled/nh367"|' -e 's|mkdir -p "$CHROOT/dgldir/inprogress-nh343"|mkdir -p "$CHROOT/dgldir/inprogress-nh367"|' -e 's|chown "$USRGRP" "$CHROOT/dgldir/inprogress-nh343"|chown "$USRGRP" "$CHROOT/dgldir/inprogress-nh367"|' -e 's|cp "$CURDIR/dgl-default-rcfile" "dgl-default-rcfile.nh343"|cp "$CURDIR/dgl-default-rcfile" "dgl-default-rcfile.nh367"|' -e 's|chmod go+r dgl_menu_main_anon.txt dgl_menu_main_user.txt dgl-banner dgl-default-rcfile.nh343|chmod go+r dgl_menu_main_anon.txt dgl_menu_main_user.txt dgl-banner dgl-default-rcfile.nh367|' ./dgl-create-chroot && \
    ./dgl-create-chroot && \
    mv /home/nethack/nh367/var/ /home/nethack/ && \
    mv -f /nh367/ /home/nethack/ && \
    cd /home/nethack/ && \
    chown -R games:games ./nh367/ && \
    sed -i -e 's/343/367/g' -e 's|chroot_path = "/opt/nethack/nethack.alt.org/"|chroot_path = "/home/nethack/"|' -e 's|"$SERVERID" = "$ATTR(14)nethack.alt.org - http://nethack.alt.org/$ATTR()"|"$SERVERID" = "$ATTR(14)***.com$ATTR()"|' -e 's|# menu_max_idle_time = 1024|menu_max_idle_time = 1024|' -e 's|game_name = "NetHack 3.4.3"|game_name = "NetHack 3.6.7"|' ./etc/dgamelaunch.conf && \
    (cp /lib/${PLATFORM}-linux-gnu/libncursesw.so.6 lib || cp /lib/${PLATFORM}-linux-gnu/libncurses.so.6 lib || true) && \
    (cd lib && [ -f libncursesw.so.6 ] && ln -s libncursesw.so.6 libncurses.so.6 || true) && \
    (echo "service telnet" && \
        echo "{" && \
        echo "  socket_type = stream" && \
        echo "  protocol    = tcp" && \
        echo "  user        = root" && \
        echo "  wait        = no" && \
        echo "  server      = /usr/sbin/in.telnetd" && \
        echo "  server_args = -h -L /home/nethack/dgamelaunch" && \
        echo "  rlimit_cpu  = 120" && \
        echo "}") > /etc/xinetd.d/dgl

# dgamelaunchのユーザーメニューのバージョンを変更
RUN sed -i 's|p) Play NetHack 3.4.3|p) Play NetHack 3.6.7|' /home/nethack/dgl_menu_main_user.txt

EXPOSE 23

CMD ["xinetd", "-dontfork"]
