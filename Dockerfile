FROM ubuntu:18.04
MAINTAINER Julian Psotta <julian@gis-ops.com>

# Set docker specific settings
ENV TERM xterm

# Install deps
RUN echo "Installing dependencies..." && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update > /dev/null && apt-get update --fix-missing > /dev/null && \
    apt-get install -y \
        # prime_server requirements
        automake locales autoconf pkg-config build-essential lcov libcurl4-openssl-dev git-core libzmq3-dev libczmq-dev \
        # Valhalla requirements
        apt-utils cmake curl wget unzip jq \
        ca-certificates gnupg2 parallel libczmq-dev libzmq5 spatialite-bin libtool \
        zlib1g-dev libsqlite3-mod-spatialite libgeos-dev libgeos++-dev libprotobuf-dev \
        protobuf-compiler libboost-all-dev libsqlite3-dev libspatialite-dev liblua5.3-dev lua5.3 \
      > /dev/null && \
    locale-gen en_US.UTF-8 && \
    # set paths to fix the libspatialite error
    ln -s /usr/lib/x86_64-linux-gnu/mod_spatialite.so /usr/lib/mod_spatialite && \
    # Create necessary folders
    mkdir -p /valhalla/scripts /valhalla/conf/valhalla_tiles

# Set language
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Export path variables
ENV SCRIPTS_DIR ${SCRIPTS_DIR:-"/valhalla/scripts"}
ENV CONFIG_PATH ${CONFIG_PATH:-"/valhalla/conf/valhalla.json"}

WORKDIR /valhalla/

# Copy all necessary build scripts
COPY scripts/. ${SCRIPTS_DIR}

ARG PRIMESERVER_RELEASE=master
RUN echo "Installing prime_server..." && \
    /bin/bash ${SCRIPTS_DIR}/build_prime_server.sh ${PRIMESERVER_RELEASE}

# Build Valhalla
ARG VALHALLA_RELEASE=master
RUN echo "Installing Valhalla..." && \
    /bin/bash ${SCRIPTS_DIR}/build_valhalla.sh ${VALHALLA_RELEASE} && \
    cp -r /valhalla/valhalla_git/scripts/. ${SCRIPTS_DIR} && \
    chmod +x ${SCRIPTS_DIR}/run.sh && \
    apt-get autoclean -y && rm -rf /valhalla/prime_server /valhalla/valhalla_git /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose the necessary port
EXPOSE 8002
CMD ${SCRIPTS_DIR}/run.sh
