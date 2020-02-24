#!/usr/bin/env bash

SCRIPTS_PATH="/valhalla/scripts"
CUSTOM_FILES="/custom_files"
CONFIG_FILE="${CUSTOM_FILES}/valhalla.json"
CUSTOM_CONFIG="${CUSTOM_FILES}/valhalla.json"

sh /valhalla/scripts/configure_valhalla.sh ${SCRIPTS_PATH} ${CONFIG_FILE} ${CUSTOM_FILES} "${tile_urls}" "${min_x}" "${max_x}" "${min_y}" "${max_y}" "${build_elevation}" "${build_admins}" "${build_time_zones}" "${force_rebuild}" "${force_rebuild_elevation}" "${use_tiles_ignore_pbf}"

if test -f ${CUSTOM_CONFIG}; then
  echo "Found config file. Starting valhalla service!"
  valhalla_service ${CUSTOM_CONFIG} 1
else
  echo "No config found!"
fi

# Keep docker running easy
exec "$@"
