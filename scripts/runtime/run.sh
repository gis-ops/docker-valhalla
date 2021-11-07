#!/usr/bin/env bash

set -e

CUSTOM_FILES="/custom_files"
CONFIG_FILE="${CUSTOM_FILES}/valhalla.json"
TILE_DIR="${CUSTOM_FILES}/valhalla_tiles"
TILE_TAR="${CUSTOM_FILES}/valhalla_tiles.tar"

build_tar=${build_tar:=True}

do_build_tar() {

  if ! test -d $TILE_DIR; then
    echo "No tiles found. Did you forget to build tiles?"
    exit 1
  fi
  
  if [[ ${build_tar} == "True" && ! -f $TILE_TAR ]] || [[ ${build_tar} == "Force" ]]; then
    valhalla_build_extract -c ${CONFIG_FILE} -v
  fi
}

# do some quick tests and provide defaults so not everything has to be set
if [[ -z "${tile_urls}" ]]; then
  tile_urls=""
fi

if [[ -z "${build_elevation}" ]]; then
  build_elevation="False"
else
  if [[ "${build_elevation}" == "True" || "${build_elevation}" == "Force" ]] && [[ -z "${min_x}" || -z "${min_y}" || -z "${max_x}" || -z "${max_y}" ]]; then
    echo ""
    echo "========================================================================="
    echo "= No valid bounding box or elevation parameter set. Skipping elevation! ="
    echo "========================================================================="
    build_elevation="True"
  fi
fi

if [[ -z "$build_admins" ]]; then
  build_admins="False"
fi

if [[ -z "$build_time_zones" ]]; then
  build_time_zones="False"
fi

if [[ -z "$force_rebuild" ]]; then
  force_rebuild="False"
fi

if [[ -z "$use_tiles_ignore_pbf" ]]; then
  use_tiles_ignore_pbf="False"
fi

if [[ -z "$server_threads" ]]; then
  server_threads=$(nproc)
fi


# evaluate CMD 
if [[ $1 == "build_tiles" ]]; then

  /bin/bash /valhalla/scripts/configure_valhalla.sh ${CONFIG_FILE} ${CUSTOM_FILES} ${TILE_DIR} ${TILE_TAR}
  # tar tiles unless not wanted
  if [[ "$build_tar" == "True" ]]; then
    do_build_tar
  else
    echo "Skipping tar building. Expect degraded performance while using Valhalla."
  fi

  if test -f ${CONFIG_FILE}; then
    echo "Found config file. Starting valhalla service!"
    valhalla_service ${CONFIG_FILE} ${server_threads}
  else
    echo "No config found!"
  fi

  # Keep docker running easy
  exec "$@"
elif [[ $1 == "tar_tiles" ]]; then
  do_build_tar
else
  echo "Unrecognized CMD: '$1'"
  exit 1
fi
