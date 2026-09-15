# Debian Trixie
FROM debian@sha256:3352c2e13876c8a5c5873ef20870e1939e73cb9a3c1aeba5e3e72172a85ce9ed
LABEL org.opencontainers.image.authors="Christy Norman <christy@linux.vnet.ibm.com>"

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

# curl
RUN apt-get update && apt-get install --yes ca-certificates curl

# Add the LLVM 23 repository.
RUN curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
        -o /etc/apt/trusted.gpg.d/apt.llvm.org.asc \
    && echo "deb https://apt.llvm.org/trixie/ llvm-toolchain-trixie-23 main" \
        > /etc/apt/sources.list.d/llvm.list

# Add buster as a source for ppc64el sysroot packages
RUN for s in debian_buster debian_buster-updates debian-security_buster/updates; do \
      echo "deb https://snapshot.debian.org/archive/${s%_*}/20250109T084424Z/ ${s#*_} main"; \
    done > /etc/apt/sources.list.d/buster.list && \
    ( echo 'quiet "true";'; \
      echo 'APT::Get::Assume-Yes "true";'; \
      echo 'APT::Install-Recommends "false";'; \
      echo 'Acquire::Check-Valid-Until "false";'; \
      echo 'Acquire::Retries "5";'; \
    ) > /etc/apt/apt.conf.d/99cpython-portable

# Pin the ppc64el sysroot packages to buster
RUN printf 'Package: *-ppc64el-cross\nPin: release n=buster\nPin-Priority: 900\n' \
        > /etc/apt/preferences.d/buster-cross

RUN apt-get update

# Host building.
RUN apt-get install \
    bzip2 \
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

# LLVM
RUN apt-get install \
    clang-23 \
    lld-23 \
    llvm-23

RUN apt-get install \
    libc6-dev-ppc64el-cross \
    libc6-ppc64el-cross \
    linux-libc-dev-ppc64el-cross \
    libgcc1-ppc64el-cross \
    libgcc-8-dev-ppc64el-cross

# Cross libc linker scripts use absolute /usr/powerpc64le-linux-gnu/lib paths,
# which the linker resolves relative to --sysroot. Mirror that prefix and
# provide the standard include/library directories in the flat cross sysroot.
RUN sysroot=/usr/powerpc64le-linux-gnu && \
    mkdir "${sysroot}/usr" && \
    ln -s .. "${sysroot}/usr/powerpc64le-linux-gnu" && \
    ln -s ../include "${sysroot}/usr/include" && \
    ln -s ../lib "${sysroot}/usr/lib"

# CPython's configure searches for a target-prefixed archiver when cross-building.
RUN ln -s /usr/lib/llvm-23/bin/llvm-ar /usr/bin/powerpc64le-unknown-linux-gnu-llvm-ar

# build-cpython.sh always prepends /tools/llvm/bin to PATH and invokes
# llvm-profdata, ld.lld, etc. from there. Satisfy those lookups with the
# apt-installed LLVM 23 binaries so the build doesn't need a downloaded
# LLVM tarball.
RUN mkdir -p /tools/llvm/bin && \
    for b in clang-23 clang++-23 clang lld-23 llvm-ar llvm-profdata llvm-objcopy; do \
        src=$(command -v "$b" 2>/dev/null || echo "/usr/lib/llvm-23/bin/$b"); \
        ln -sf "$src" "/tools/llvm/bin/$b"; \
    done && \
    ln -sf /usr/lib/llvm-23/bin/lld /tools/llvm/bin/ld.lld && \
    ln -sf /usr/lib/llvm-23/bin/lld /tools/llvm/bin/lld && \
    ln -sf clang-23 /tools/llvm/bin/clang && \
    ln -sf clang++-23 /tools/llvm/bin/clang++
