#!/usr/bin/env bash

set -e

SCRIPTS_PATH="/valhalla/scripts"
CUSTOM_FILES="/custom_files"
CONFIG_FILE="${CUSTOM_FILES}/valhalla.json"
CUSTOM_CONFIG="${CUSTOM_FILES}/valhalla.json"

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
    build_elevation="False"
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
  server_threads=$(expr $(nproc) - 1)
fi

/bin/bash /valhalla/scripts/configure_valhalla.sh ${SCRIPTS_PATH} ${CONFIG_FILE} ${CUSTOM_FILES} "${tile_urls}" "${min_x}" "${max_x}" "${min_y}" "${max_y}" "${build_elevation}" "${build_admins}" "${build_time_zones}" "${force_rebuild}" "${use_tiles_ignore_pbf}"

if test -f ${CUSTOM_CONFIG}; then
  echo "Found config file. Starting valhalla service!"
  valhalla_service ${CUSTOM_CONFIG} ${server_threads}
else
  echo "No config found!"
fi

# Keep docker running easy
exec "$@"
