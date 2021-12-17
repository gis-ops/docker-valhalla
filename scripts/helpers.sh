# helper functions

# create global variables
CUSTOM_FILES="/custom_files"
# if the user requested a path_extension, apply it
if [[ -n $path_extension ]]; then
  CUSTOM_FILES="${CUSTOM_FILES}/${path_extension}"
fi
if ! test -d "${CUSTOM_FILES}"; then
  mkdir "${CUSTOM_FILES}"
fi

CONFIG_FILE="${CUSTOM_FILES}/valhalla.json"
TILE_DIR="${CUSTOM_FILES}/valhalla_tiles"
TILE_TAR="${CUSTOM_FILES}/valhalla_tiles.tar"
HASH_FILE="${CUSTOM_FILES}/file_hashes.txt"
ADMIN_DB="${CUSTOM_FILES}/admin_data/admins.sqlite"
TIMEZONE_DB="${CUSTOM_FILES}/timezone_data/timezones.sqlite"
ELEVATION_PATH="${CUSTOM_FILES}/elevation_data"

maybe_create_dir() {
  if ! test -d $1; then
  	mkdir $1
  fi
}

hash_counter() {
  old_hashes=""
  counter=0
  # Read the old hashes
  while IFS="" read -r line || [[ -n "$line" ]]; do
    old_hashes="${old_hashes} ${line}"
  done < "${HASH_FILE}"
  for hash in ${old_hashes}; do
    counter=$((counter + 1))
  done
  echo "${counter}"
}

hash_exists() {
  old_hashes=""
  # Read the old hashes
  cat "${HASH_FILE}"
  while IFS="" read -r line || [[ -n "$line" ]]; do
    old_hashes="${old_hashes} ${line}"
  done < "${HASH_FILE}"
  hash=$(printf '%s' "${1}" | sha256sum | cut -f1 -d' ')
  if [[ ${old_hashes} =~ ${hash} ]]; then
    echo "True"
  else
    echo "False"
  fi
}

add_hashes() {
  # Add FILES to the hash list to check for updates on rerun.
  hashes=""
  rm -f ${HASH_FILE}
  echo "INFO: Hashing files: ${1}"
  for value in ${1}; do
    echo "INFO: Hashing file: ${value}"
    hash="$(printf '%s' "${value}" | sha256sum | cut -f1 -d' ')"
    hashes="${hashes} $hash"
  done
  echo ${hashes} >> ${HASH_FILE}
  cat ${HASH_FILE}
}

download_file() {
  if curl --location --output /dev/null --silent --show-error --head --fail "${1}"; then
    echo ""
    echo "==============================================================="
    echo " Downloading  ${url}"
    echo "==============================================================="
    curl --location -o "${2}" ${url}
  else
    echo "ERROR: Couldn't download from ${url}."
    exit 1
  fi
}
