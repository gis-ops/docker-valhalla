FROM gisops/prime_server-nodejs:latest-10.15.0
MAINTAINER Julian Psotta <julian@gis-ops.com>

# Set docker specific settings
ENV TERM xterm
RUN export DEBIAN_FRONTEND=noninteractive

# Install deps
RUN apt-get update && apt-get update --fix-missing

# Install dependencies
RUN apt-get install -y apt-utils dialog locales aptitude cmake build-essential autoconf pkg-config wget curl \
                        ca-certificates gnupg2 git parallel libczmq-dev libzmq5 spatialite-bin unzip libtool \
                        zlib1g-dev libsqlite3-mod-spatialite jq libgeos-dev libgeos++-dev libprotobuf-dev \
                        protobuf-compiler libboost-all-dev libsqlite3-dev libspatialite-dev  liblua5.3-dev lua5.3

# Set locales
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# set paths to fix the libspatialite error
RUN ln -s /usr/lib/x86_64-linux-gnu/mod_spatialite.so /usr/lib/mod_spatialite

# Create necessary folders
RUN mkdir -p /valhalla/scripts /valhalla/conf/valhalla_tiles

# Export path variables
ENV SCRIPTS_DIR ${SCRIPTS_DIR:-"/valhalla/scripts"}
ENV CONFIG_PATH ${CONFIG_PATH:-"/valhalla/conf/valhalla.json"}

WORKDIR /valhalla/

# Copy build script
COPY scripts/build_valhalla.sh ${SCRIPTS_DIR}

# Build Valhalla
ARG version
RUN /bin/bash ${SCRIPTS_DIR}/build_valhalla.sh ${version}

# Copy scripts for later use
RUN cp -r /valhalla/valhalla_git/scripts/. ${SCRIPTS_DIR}
COPY scripts/run.sh ${SCRIPTS_DIR}

# Make the files accessible
RUN chmod +x ${SCRIPTS_DIR}/run.sh

# Delete build files
RUN apt-get autoclean -y && rm -rf /valhalla/valhalla_git /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Change dirctory to the main script files
WORKDIR /${SCRIPTS_DIR}

# Add scripts for production use
COPY scripts/configure_valhalla.sh ${SCRIPTS_DIR}

# Expose the necessary port
EXPOSE 8002
ENTRYPOINT ["/bin/bash", "/valhalla/scripts/run.sh"]
