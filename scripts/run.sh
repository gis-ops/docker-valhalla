#!/usr/bin/env bash

set -e

# source the helpers for globals and functions
. /valhalla/scripts/helpers.sh

# we need to either run commands that create files with or without sudo (depends if the image was built with a UID/GID other than 0)
run_cmd() {
  if [[ ${dir_owner} == "root" ]]; then
    # -E preserves the env vars
    sudo -E $1 || exit 1
  else
    $1 || exit 1
  fi
}

do_build_tar() {
  if ! test -d $TILE_DIR; then
    echo "ERROR: No tiles found. Did you forget to build tiles?"
    exit 1
  fi
  
  if [[ ${build_tar} == "True" && ! -f $TILE_TAR ]] || [[ ${build_tar} == "Force" ]]; then
    run_cmd "valhalla_build_extract -c ${CONFIG_FILE} -v"
  fi
}

# find out the owner of the mapped volume and warn if it's root
dir_owner=$(stat --format '%U' "${CUSTOM_FILES}")
echo ""
echo "INFO: Running container with user $(whoami) UID $(id --user) and GID $(id --group)."
if [[ ${dir_owner} == "root" ]]; then
  echo "WARNING: User $(whoami) is running with sudo privileges. Try building the image with a host user's UID & GID."
  if [[ "${VALHALLA_UID}" != 0 ]] || [[ "${VALHALLA_GID}" != 0 ]]; then
    echo "ERROR: If you run with custom UID or GID you have to create the mapped directory to the container's /custom_files manually before starting the image"
    exit 1
  fi
fi
echo ""

# the env vars with True default are set in the dockerfile, others are evaluated in configure_valhalla.sh
if [[ -z "$server_threads" ]]; then
  server_threads=$(nproc)
fi

# evaluate CMD 
if [[ $1 == "build_tiles" ]]; then

  run_cmd "/valhalla/scripts/configure_valhalla.sh ${CONFIG_FILE} ${CUSTOM_FILES} ${TILE_DIR} ${TILE_TAR}" 
  # tar tiles unless not wanted
  if [[ "$build_tar" == "True" ]]; then
    do_build_tar
  else
    echo "WARNING: Skipping tar building. Expect degraded performance while using Valhalla."
  fi

  # set 775/664 permissions on all created files
  find "${CUSTOM_FILES}" -type d -exec chmod 775 {} \;
  find "${CUSTOM_FILES}" -type f -exec chmod 664 {} \;

  if test -f ${CONFIG_FILE}; then
    echo "INFO: Found config file. Starting valhalla service!"
    run_cmd "valhalla_service ${CONFIG_FILE} ${server_threads}"
  else
    echo "WARNING: No config found!"
  fi

  # Keep docker running easy
  exec "$@"
  
elif [[ $1 == "tar_tiles" ]]; then
  do_build_tar
else
  echo "ERROR: Unrecognized CMD: '$1'"
  exit 1
fi
