# Debian Sid (ships GCC 15, which supports -mcpu=power11).
FROM debian@sha256:7469781d68f44940c9494eeba6e7ab89063947f794320d61c193bf027aeb7761
LABEL org.opencontainers.image.authors="Gregory Szorc <gregory.szorc@gmail.com>"

RUN groupadd -g 1000 build && \
    useradd -u 1000 -g 1000 -d /build -s /bin/bash -m build && \
    mkdir /tools && \
    chown -R build:build /build /tools

ENV HOME=/build \
    SHELL=/bin/bash \
    USER=build \
    LOGNAME=build \
    HOSTNAME=builder \
    DEBIAN_FRONTEND=noninteractive

CMD ["/bin/bash", "--login"]
WORKDIR '/build'

RUN echo "deb http://snapshot.debian.org/archive/debian/20260601T000000Z/ sid main" \
      > /etc/apt/sources.list && \
    ( echo 'quiet "true";'; \
      echo 'APT::Get::Assume-Yes "true";'; \
      echo 'APT::Install-Recommends "false";'; \
      echo 'Acquire::Check-Valid-Until "false";'; \
      echo 'Acquire::Retries "5";'; \
    ) > /etc/apt/apt.conf.d/99cpython-portable && \
    rm -f /etc/apt/sources.list.d/*

RUN apt-get update

# Host building.
RUN apt-get install \
    bzip2 \
    ca-certificates \
    gcc \
    g++ \
    libc6-dev \
    libffi-dev \
    make \
    patch \
    perl \
    pkg-config \
    tar \
    xz-utils \
    unzip \
    zip \
    zlib1g-dev

# Cross-building (powerpc64le only — GCC 15 supports -mcpu=power11).
RUN apt-get install \
    g++-15-powerpc64le-linux-gnu \
    gcc-15-powerpc64le-linux-gnu \
    libc6-dev-ppc64el-cross
