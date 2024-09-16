# Take the official valhalla runner image,
# remove a few superfluous things and
# create a new runner image from ubuntu:24.04
# with the previous runner's artifacts
ARG VALHALLA_BUILDER_IMAGE=ghcr.io/valhalla/valhalla:latest
FROM $VALHALLA_BUILDER_IMAGE as builder
MAINTAINER Nils Nolde <nils@gis-ops.com>

# remove some stuff from the original image
RUN cd /usr/local/bin && \
  preserve="valhalla_service valhalla_build_tiles valhalla_build_config valhalla_build_admins valhalla_build_timezones valhalla_build_elevation valhalla_ways_to_edges valhalla_build_extract valhalla_export_edges valhalla_add_predicted_traffic valhalla_ingest_transit valhalla_convert_transit valhalla_add_landmarks valhalla_build_landmarks" && \
  mv $preserve .. && \
  for f in valhalla*; do rm $f; done && \
  cd .. && mv $preserve ./bin

FROM ubuntu:24.04 as runner_base
MAINTAINER Nils Nolde <nils@gis-ops.com>

RUN apt-get update > /dev/null && \
  export DEBIAN_FRONTEND=noninteractive && \
  apt-get install -y libluajit-5.1-2 libgdal34 \
  libzmq5 libczmq4 spatialite-bin libprotobuf-lite32 sudo locales \
  libsqlite3-0 libsqlite3-mod-spatialite libcurl4 \
  python3.12-minimal python3-requests python3-shapely python-is-python3 \
  curl unzip moreutils jq spatialite-bin > /dev/null

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/local/lib/python3.12/dist-packages/valhalla /usr/local/lib/python3.12/dist-packages/

ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"
# export the True defaults
ENV use_tiles_ignore_pbf=True
ENV build_tar=True
ENV serve_tiles=True
ENV update_existing_config=True

ENV default_speeds_config_url="https://raw.githubusercontent.com/OpenStreetMapSpeeds/schema/master/default_speeds.json"

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
RUN python -c "import valhalla,sys; print (sys.version, valhalla)" \
  && valhalla_build_config | jq type \
  && cat /usr/local/src/valhalla_version \
  && valhalla_build_tiles -v \
  && ls -la /usr/local/bin/valhalla*

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib32:/usr/lib32

# Expose the necessary port
EXPOSE 8002
ENTRYPOINT ["/valhalla/scripts/run.sh"]
CMD ["build_tiles"]
