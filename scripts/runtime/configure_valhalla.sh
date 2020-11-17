#!/usr/bin/env bash

# create global variables
files=""
files_counter=0
skip_build=0
tile_files=""
script_path=${1}
config_file=${2}
echo "TEST: ${3}"
custom_tile_folder=${3}
tile_urls=${4}
min_x=${5}
max_x=${6}
min_y=${7}
max_y=${8}
build_elevation=${9}
build_admins=${10}
build_time_zones=${11}
force_rebuild=${12}
force_rebuild_elevation=${13}
use_tiles_only=${14}

hash_counter() {
  # The first parameter is the location path of the tile file without the hash filename.
  # That is handled internally. The second is the file with path that should be matched against the existing tiles hashes.
  current_directory=${PWD}
  cd ${1}
  if ! [[ -f ".file_hashes.txt" ]]; then
    echo "Hash counter couldn't find hash file!"
    cd ${current_directory}
    return 0
  fi

  old_hashes=""
  counter=-1
  # Read the old hashes
  while IFS="" read -r line || [[ -n "$line" ]]; do
    echo "Scanning old hash ${line}"
    old_hashes="${old_hashes} ${line}"
  done <".file_hashes.txt"
  for hash in ${old_hashes}; do
    counter=$((counter + 1))
  done
  return ${counter}
}

hash_exists() {
  # The first parameter is the location path of the tile file without the hash filename.
  # That is handled internally. The second is the file with path that should be matched against the existing tiles hashes.
  current_directory=${PWD}
  cd ${1}
  if ! [[ -f ".file_hashes.txt" ]]; then
    echo "Couldn't find .file_hashes.txt"
    cd ${current_directory}
    return 1
  fi

  old_hashes=""
  cat .file_hashes.txt
  # Read the old hashes
  while IFS="" read -r line || [[ -n "$line" ]]; do
    old_hashes="${old_hashes} ${line}"
  done <".file_hashes.txt"
  hash="$(printf '%s' "${2}" | sha256sum | cut -f1 -d' ')"
  cd ${current_directory}
  if [[ ${old_hashes} == *"${hash}"* ]]; then
    echo "Found valid hash for ${2}!"
    return 0
  else
    return 1
  fi
}

add_hashes() {
  # Add files to the hash list to check for updates on rerun.
  # First parameter is the path where the hash file should be stored.
  # The second is the string of file names with path.
  current_directory=${PWD}
  cd ${1}
  hashes=""
  rm -rf .file_hashes.txt
  echo "Hashing files: ${2}"
  for value in ${2}; do
    echo "Hashing file: ${value}"
    hash="$(printf '%s' "${value}" | sha256sum | cut -f1 -d' ')"
    hashes="${hashes} $hash"
  done
  echo ${hashes} >>.file_hashes.txt
  cat .file_hashes.txt
  cd ${current_directory}
}

download_files() {
  # $1 destination folder
  # $2 files in one string with space as separator
  current_diretory=${PWD}
  cd ${1}
  echo "PATH0: ${0}"
  echo "PATH1: ${1}"
  echo "PATH2: ${2}"
  download_counter=0
  for url in ${2}; do
    echo "URL: ${url}"
    if curl --output /dev/null --silent --head --fail "${url}"; then
      echo ""
      echo "==============================================================="
      echo " Downloading  ${url}"
      echo "==============================================================="
      curl -O ${url}
      download_counter=$((download_counter + 1))
      # Assign the file name of the osm extract for later use
    fi
    if [[ ${download_counter} == 0 ]]; then
      echo "Couldn't download any files. Check your links or add local pbf files!"
      exit 1
    fi
  done

}

build_config () {
  # Create build folder if they don't exist
  mkdir -p ${custom_tile_folder}/{timezone_data,admin_data,elevation_data}

  # Go to scripts folder
  cd ${script_path}

  # Check for bounding box
  mjolnir_timezone=""
  mjolnir_admin=""
  additional_data_elevation=""

  # Adding the desired modules
  if [[ ${build_elevation} == "True" ]] && [[ "${min_x}" != 0 ]] && [[ "${max_x}" != 0 ]] && [[ "${min_y}" != 0 ]] && [[ "${max_y}" != 0 ]]; then
    echo ""
    echo "============================================================================"
    echo "= Valid bounding box and data elevation parameter added. Adding elevation! ="
    echo "============================================================================"
    if [[ ${force_rebuild_elevation} == "True" ]]; then
      echo "Rebuilding elevation tiles"
      rm -rf "${custom_tile_folder}/elevation_data"
      mkdir -p "${custom_tile_folder}/elevation_data"
    fi
    # Build the elevation data
    valhalla_build_elevation ${min_x} ${max_x} ${min_y} ${max_y} ${custom_tile_folder}/elevation_data
    additional_data_elevation="--additional-data-elevation ${custom_tile_folder}/elevation_data"
  else
    echo ""
    echo "========================================================================="
    echo "= No valid bounding box or elevation parameter set. Skipping elevation! ="
    echo "========================================================================="
  fi

  if [[ ${build_admins} == "True" ]]; then
    # Add admin path
    echo ""
    echo "========================"
    echo "= Adding admin regions ="
    echo "========================"
    mjolnir_admin="--mjolnir-admin ${custom_tile_folder}/admin_data/admins.sqlite"
  else
    echo ""
    echo "=========================="
    echo "= Skipping admin regions ="
    echo "=========================="
  fi

  if [[ ${build_time_zones} == "True" ]]; then
    echo ""
    echo "========================"
    echo "= Adding timezone data ="
    echo "========================"
    mjolnir_timezone="--mjolnir-timezone ${custom_tile_folder}/timezone_data/timezones.sqlite"
  else
    echo ""
    echo "=========================="
    echo "= Skipping timezone data ="
    echo "=========================="
  fi

  if ! test -f "${config_file}"; then
    echo ""
    echo "========================="
    echo "= Build the config file ="
    echo "========================="

    valhalla_build_config --mjolnir-tile-dir ${script_path}/valhalla_tiles --mjolnir-tile-extract ${custom_tile_folder}/valhalla_tiles.tar ${mjolnir_timezone} ${mjolnir_admin} ${additional_data_elevation} >${config_file}
  else
    echo ""
    echo "=========================="
    echo "= Using existing config file ="
    echo "=========================="
  fi
}

build_db () {
  # Build the desired modules with the config file
  if [[ ${build_admins} == "True" ]]; then
    # Build the admin regions
    echo ""
    echo "==========================="
    echo "= Build the admin regions ="
    echo "==========================="
    valhalla_build_admins --config ${config_file} ${files}
  fi

  if [[ ${build_time_zones} == "True" ]]; then
    # Build the time zones
    echo ""
    echo "==========================="
    echo "= Build the timezone data ="
    echo "==========================="
    ./valhalla_build_timezones > ${custom_tile_folder}/timezone_data/timezones.sqlite
  fi
}

# Check for custom file folder and create if it doesn't exist.
if ! test -f "${custom_tile_folder}"; then
  mkdir -p ${custom_tile_folder}
fi

# Go into custom tiles folder
cd ${custom_tile_folder}

# Check if valhalla_tiles.tar exists
if test -f "${custom_tile_folder}/valhalla_tiles.tar"; then
  echo "Valid valhalla_tiles.tar found with use_tiles_ignore_pbf: ${use_tiles_only}!"
  if [[ ${use_tiles_only} == "True" ]]; then
    echo "Jumping directly to the tile loading!"
    build_config
    build_db
    exit 0
  else
    echo "Build new valhalla_tiles.tar from available PBF(s)."
    skip_build=0
  fi
else
  echo "Valhalla tiles not found!"
  skip_build=1
fi

# Find and add .pbf files to the list of files
for file in *.pbf; do
  [[ -f "$file" ]] || break
  if ! hash_exists ${custom_tile_folder} "${custom_tile_folder}/${file}"; then
    echo "Hash not found for: ${file}!"
    skip_build=1
  fi
  files="${files} ${PWD}/${file}"
  files_counter=$((files_counter + 1))
done

hash_counter ${custom_tile_folder}
hashes=${?}

if test -f "${custom_tile_folder}/valhalla_tiles.tar" && [[ ${skip_build} == 0 ]] && [[ ${hashes} == ${files_counter} ]] && [[ ${force_rebuild} == "False" ]]; then
  echo "All files have already been build and valhalla_tiles.tar exists and is valid. Starting without new build!"
  echo "PBF hashes: $hashes"
  echo "PBF file Counter: $files_counter"
  echo "Found valhalla_tiles.tar!"
  build_config
  build_db
  exit 0
else
  echo "Either valhalla_tiles.tar couldn't be found or new files or file constellations were detected. Rebuilding files: ${files}"
  echo "PBF hashes: $hashes"
  echo "PBF file Counter: $files_counter"
fi

if [[ ${force_rebuild} == "True" ]]; then
  echo "Detected forced rebuild. Deleting old files!"
  rm -rf "${custom_tile_folder}/valhalla_tiles.tar"
  rm -rf "${custom_tile_folder}/timezone_data"
  rm -rf "${custom_tile_folder}/admin_data"
  rm -rf "${custom_tile_folder}/.file_hashes.txt"
  echo "Counter: $files_counter"
  skip_build=1
fi

if [[ ${files_counter} == 0 ]] && [[ ${skip_build} == 1 ]]; then
  echo "No local files and no valhalla_tiles.tar found. Downloading links: ${tile_urls}!"
  download_files "${custom_tile_folder}" "${tile_urls}"
  skip_build=1
fi

if [[ ${files_counter} == 0 ]]; then
  # Find and add .pbf files to the list of files that were just downloaded
  for file in *.pbf; do
    [[ -f "$file" ]] || break
    if ! hash_exists ${custom_tile_folder} "${custom_tile_folder}/${file}"; then
      echo "Hash not found for: ${file}!"
      skip_build=1
    fi
    files="${files} ${custom_tile_folder}/${file}"
    files_counter=$((files_counter + 1))
  done
fi

build_config

build_db

# Finally build the tiles
echo ""
echo "========================="
echo "= Build the tile files. ="
echo "========================="
echo "Running build tiles with: ${config_file} ${files}"
valhalla_build_tiles -c ${config_file} ${files}	|| exit 1
find valhalla_tiles | sort -n | tar cf "${custom_tile_folder}/valhalla_tiles.tar" --no-recursion -T -
cd ${custom_tile_folder}

echo "Successfully build files: ${files}"
add_hashes ${custom_tile_folder} "${files}"
