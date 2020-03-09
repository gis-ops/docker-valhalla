FROM gisops/prime_server-nodejs:latest-10.15.0
MAINTAINER Julian Psotta <julian@gis-ops.com>

# Set docker specific settings
ENV TERM xterm

# Install deps
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && apt-get update --fix-missing && \
    apt-get install -y apt-utils dialog locales aptitude cmake build-essential autoconf pkg-config wget curl \
                        ca-certificates gnupg2 git parallel libczmq-dev libzmq5 spatialite-bin unzip libtool \
                        zlib1g-dev libsqlite3-mod-spatialite jq libgeos-dev libgeos++-dev libprotobuf-dev \
                        protobuf-compiler libboost-all-dev libsqlite3-dev libspatialite-dev  liblua5.3-dev lua5.3 && \
    locale-gen en_US.UTF-8 && \
    # set paths to fix the libspatialite error
    ln -s /usr/lib/x86_64-linux-gnu/mod_spatialite.so /usr/lib/mod_spatialite && \
    # Create necessary folders
    mkdir -p /valhalla/scripts /valhalla/conf/valhalla_tiles

# Set locales
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Export path variables
ENV SCRIPTS_DIR ${SCRIPTS_DIR:-"/valhalla/scripts"}
ENV CONFIG_PATH ${CONFIG_PATH:-"/valhalla/conf/valhalla.json"}

WORKDIR /valhalla/

# Copy all necessary build scripts
COPY scripts/. ${SCRIPTS_DIR}

# Build Valhalla
ARG version
RUN /bin/bash ${SCRIPTS_DIR}/build_valhalla.sh ${version} && \
    # Copy scripts for later use
    cp -r /valhalla/valhalla_git/scripts/. ${SCRIPTS_DIR} && \
    chmod +x ${SCRIPTS_DIR}/run.sh && \
    apt-get autoclean -y && rm -rf /valhalla/valhalla_git /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose the necessary port
EXPOSE 8002
ENTRYPOINT ["/bin/bash", "/valhalla/scripts/run.sh"]
