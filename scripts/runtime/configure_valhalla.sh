#!/usr/bin/env bash

# create global variables
files=""
files_counter=0
do_build="False"
tile_files=""
script_path=${1}
config_file=${2}
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
use_tiles_only=${13}

hash_file="${custom_tile_folder}/.file_hashes.txt"

admin_db="${custom_tile_folder}/admin_data/admins.sqlite"
timezone_db="${custom_tile_folder}/timezone_data/timezones.sqlite"
elevation_path="${custom_tile_folder}/elevation_data"

hash_counter() {
  old_hashes=""
  counter=0
  # Read the old hashes
  while IFS="" read -r line || [[ -n "$line" ]]; do
    old_hashes="${old_hashes} ${line}"
  done <"${hash_file}"
  for hash in ${old_hashes}; do
    counter=$((counter + 1))
  done
  echo ${counter}
}

hash_exists() {
  old_hashes=""
  cat ${hash_file}
  # Read the old hashes
  while IFS="" read -r line || [[ -n "$line" ]]; do
    old_hashes="${old_hashes} ${line}"
  done <"${hash_file}"
  hash="$(printf '%s' "${1}" | sha256sum | cut -f1 -d' ')"
  if [[ ${old_hashes} == *"${hash}"* ]]; then
    echo True
  else
    echo False
  fi
}

add_hashes() {
  # Add files to the hash list to check for updates on rerun.
  hashes=""
  rm -f ${hash_file}
  echo "Hashing files: ${1}"
  for value in ${1}; do
    echo "Hashing file: ${value}"
    hash="$(printf '%s' "${value}" | sha256sum | cut -f1 -d' ')"
    hashes="${hashes} $hash"
  done
  echo ${hashes} >> ${hash_file}
  cat ${hash_file}
}

download_files() {
  current_dir=${PWD}
  cd ${custom_tile_folder}
  download_counter=0

  for url in ${1}; do
    if curl --location --output /dev/null --silent --head --fail "${url}"; then
      echo ""
      echo "==============================================================="
      echo " Downloading  ${url}"
      echo "==============================================================="
      curl --location -O ${url}
      download_counter=$((download_counter + 1))
      # Assign the file name of the osm extract for later use
    fi
    if [[ ${download_counter} == 0 ]]; then
      echo "Couldn't download any files. Check your links or add local pbf files!"
      exit 1
    fi
  done

  cd $current_dir
}

build_config () {
  mjolnir_timezone=""
  mjolnir_admin=""
  additional_data_elevation=""

  # Adding the desired modules
  if [[ ${build_elevation} == "True" || ${build_elevation} == "Force" ]]; then
    additional_data_elevation="--additional-data-elevation $elevation_path"
  fi

  if [[ ${build_admins} == "True" || ${build_admins} == "Force" ]]; then
    mjolnir_admin="--mjolnir-admin $admin_db"
  fi

  if [[ ${build_time_zones} == "True" || ${build_time_zones} == "Force" ]]; then
    mjolnir_timezone="--mjolnir-timezone $timezone_db"
  fi

  if ! test -f "${config_file}"; then
    echo ""
    echo "========================="
    echo "= Build the config file ="
    echo "========================="

    valhalla_build_config --mjolnir-tile-dir ${script_path}/valhalla_tiles --mjolnir-tile-extract ${custom_tile_folder}/valhalla_tiles.tar ${mjolnir_timezone} ${mjolnir_admin} ${additional_data_elevation} --mjolnir-traffic-extract "" --mjolnir-transit-dir "" > ${config_file}
  else
    echo ""
    echo "=========================="
    echo "= Using existing config file ="
    echo "=========================="
  fi
}

build_extras () {
  # Only build the dbs if forced or the files don't exist

  if [[ ${build_admins} == "True" && ! -f $admin_db ]] || [[ ${build_admins} == "Force" ]]; then
    echo ""
    echo "==========================="
    echo "= Build the admin regions ="
    echo "==========================="
    valhalla_build_admins --config ${config_file} ${files}
  else
    echo ""
    echo "=========================="
    echo "= Skipping admin regions ="
    echo "=========================="
  fi

  if [[ ${build_time_zones} == "True" && ! -f $timezone_db ]] || [[ ${build_time_zones} == "Force" ]]; then
    echo ""
    echo "==========================="
    echo "= Build the timezone data ="
    echo "==========================="
    valhalla_build_timezones > ${custom_tile_folder}/timezone_data/timezones.sqlite
  else
    echo "=========================="
  fi


  if [[ ${build_elevation} == "True" || ${build_elevation} == "Force" ]]; then
    if [[ ${force_rebuild_elevation} == "Force" ]]; then
      echo "Rebuilding elevation tiles"
      rm -rf $elevation_path
      mkdir -p $elevation_path
    fi
    # Build the elevation data
    echo ""
    echo "==========================="
    echo "= Download the elevation tiles ="
    echo "==========================="
    valhalla_build_elevation ${min_x} ${max_x} ${min_y} ${max_y} $elevation_path
  fi
}

# Check for custom file folder and create if it doesn't exist.
if ! test -d "${custom_tile_folder}"; then
  mkdir -p ${custom_tile_folder}
fi

# Same for hashes file
if ! test -f "${hash_file}"; then
  touch ${hash_file}
fi

# Create build folder if they don't exist
dirs="timezone_data admin_data elevation_data"
for d in $dirs; do
  if ! test -d $custom_tile_folder/$d; then
    mkdir $custom_tile_folder/$d
  fi
done

# Check if valhalla_tiles.tar exists
if test -f "${custom_tile_folder}/valhalla_tiles.tar"; then
  echo "Valid valhalla_tiles.tar found with use_tiles_ignore_pbf: ${use_tiles_only}!"
  if [[ ${use_tiles_only} == "True" ]]; then
    echo "Jumping directly to the tile loading!"
    build_config
    build_extras
    exit 0
  fi
else
  echo "Valhalla tiles not found!"
  do_build="True"
fi

# Find and add .pbf files to the list of files
for file in $(ls $custom_tile_folder/*.pbf); do
  if [[ ! $(hash_exists ${file}) == *"True" ]] ; then
    echo "Hash not found for: ${file}!"
    do_build="True"
  fi
  files="${files} ${file}"
  files_counter=$((files_counter + 1))
done



hashes=$(hash_counter)

if [[ ${force_rebuild} == "True" ]]; then
  echo "Detected forced rebuild. Deleting old files!"
  rm -rf "${custom_tile_folder}/valhalla_tiles.tar"
  rm -rf "${custom_tile_folder}/.file_hashes.txt"
  echo "PBF file Counter: $files_counter"
  do_build="True"
fi

if [[ -f "${custom_tile_folder}/valhalla_tiles.tar" && ${do_build} == "False" && ${hashes} == ${files_counter} ]]; then
  echo "All files have already been build and valhalla_tiles.tar exists and is valid. Starting without new build!"
  echo "PBF hashes: $hashes"
  echo "PBF file Counter: $files_counter"
  echo "Found valhalla_tiles.tar!"
  build_config
  build_extras
  exit 0
else
  echo "Either valhalla_tiles.tar couldn't be found or new files or file constellations were detected. Rebuilding files: ${files}"
  echo "PBF hashes: $hashes"
  echo "PBF file Counter: $files_counter"
fi

if [[ ${files_counter} == 0 ]] && [[ ${do_build} == "True" ]]; then
  if [[ -z "${tile_urls}" ]]; then
    echo "No local PBF files, valhalla_tiles.tar and no tile URLs found. Nothing to do."
    exit 1
  else
    echo "No local files and no valhalla_tiles.tar found. Downloading links: ${tile_urls}!"
    download_files "${tile_urls}"
    do_build="True"
  fi
fi

if [[ ${files_counter} == 0 ]]; then
  # Find and add .pbf files to the list of files that were just downloaded
  for file in $(ls $custom_tile_folder/*.pbf); do
    echo "${file}"
    if [[ ! $(hash_exists ${file}) == "True" ]]; then
      echo "Hash not found for: ${file}!"
      do_build="True"
    else
      echo "Hash found for: ${file}"
    fi
    files="${files} ${file}"
    files_counter=$((files_counter + 1))
  done
fi

build_config
build_extras

# Finally build the tiles
echo ""
echo "========================="
echo "= Build the tile files. ="
echo "========================="
echo "Running build tiles with: ${config_file} ${files}"
valhalla_build_tiles -c ${config_file} ${files}	|| exit 1
find ${script_path}/valhalla_tiles | sort -n | tar cf "${custom_tile_folder}/valhalla_tiles.tar" --no-recursion -T -

echo "Successfully built files: ${files}"
add_hashes "${files}"
