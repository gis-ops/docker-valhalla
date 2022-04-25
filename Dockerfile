# Take the official valhalla runner image,
# remove a few superfluous things and
# create a new runner image from ubuntu:20.04
# with the previous runner's artifacts

FROM valhalla/valhalla:run-latest as builder
MAINTAINER Nils Nolde <nils@gis-ops.com>

# remove some stuff from the original image
RUN cd /usr/local/bin && \
  preserve="valhalla_service valhalla_build_tiles valhalla_build_config valhalla_build_admins valhalla_build_timezones valhalla_build_elevation valhalla_ways_to_edges valhalla_build_extract" && \
  mv $preserve .. && \
  for f in valhalla*; do rm $f; done && \
  cd .. && mv $preserve ./bin

FROM ubuntu:20.04 as runner_base
MAINTAINER Nils Nolde <nils@gis-ops.com>

RUN apt-get update > /dev/null && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y libluajit-5.1-2 \
      libzmq5 libczmq4 spatialite-bin libprotobuf-lite17 sudo locales \
      libsqlite3-0 libsqlite3-mod-spatialite libgeos-3.8.0 libcurl4 \
      python3.8-minimal python3-distutils curl unzip moreutils jq spatialite-bin > /dev/null && \
    ln -sf /usr/bin/python3.8 /usr/bin/python && \
    ln -sf /usr/bin/python3.8 /usr/bin/python3

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/bin/prime_* /usr/bin/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libprime* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/python3/dist-packages/valhalla/* /usr/lib/python3/dist-packages/valhalla/

ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"
# export the True defaults
ENV use_tiles_ignore_pbf=True
ENV build_tar=True
ENV serve_tiles=True

# what this does:
# if the docker user specified a UID/GID (other than 0, would be a ludicrous instruction anyways) in the image build, we will use that to create the valhalla linux user in the image. that ensures that the docker user can edit the created files on the host without sudo and with 664/775 permissions, so that users of that group can also write. the default is to give the valhalla user passwordless sudo. that also means that all commands creating files in the entrypoint script need to be executed with sudo when built with defaults..
# based on https://jtreminio.com/blog/running-docker-containers-as-current-host-user/, but this use case needed a more customized approach

# with that we can properly test if the default was used or not
ARG VALHALLA_UID=59999
ARG VALHALLA_GID=59999

RUN groupadd -g ${VALHALLA_GID} valhalla && \
  useradd -lmu ${VALHALLA_UID} -g valhalla valhalla && \
  mkdir /custom_files && \
  if [ $VALHALLA_UID != 59999 ] || [ $VALHALLA_GID != 59999 ]; then chmod 0775 custom_files && chown valhalla:valhalla /custom_files; else usermod -aG sudo valhalla && echo "ALL            ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers; fi

COPY scripts/. /valhalla/scripts

USER valhalla

WORKDIR /custom_files

# Smoke tests
RUN    python3 -c "import valhalla,sys; print (sys.version, valhalla)" \
    && valhalla_build_config | jq type \
    && cat /usr/local/src/valhalla_version \
    && valhalla_build_tiles -v \
    && ls -la /usr/local/bin/valhalla*

# Expose the necessary port
EXPOSE 8002
ENTRYPOINT ["/valhalla/scripts/run.sh"]
CMD ["build_tiles"]
