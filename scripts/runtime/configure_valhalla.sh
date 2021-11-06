#!/usr/bin/env bash

# create global variables
config_file=${1}
custom_folder=${2}
tile_dir=${3}
tile_extract=${4}

files=""
files_counter=0
do_build="False"
hash_file="${custom_folder}/.file_hashes.txt"
admin_db="${custom_folder}/admin_data/admins.sqlite"
timezone_db="${custom_folder}/timezone_data/timezones.sqlite"
elevation_path="${custom_folder}/elevation_data"

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
  cd ${custom_folder}
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

    valhalla_build_config --mjolnir-tile-dir ${tile_dir} --mjolnir-tile-extract ${tile_extract} ${mjolnir_timezone} ${mjolnir_admin} ${additional_data_elevation} --mjolnir-traffic-extract "" --mjolnir-transit-dir "" > ${config_file}
  else
    echo ""
    echo "=========================="
    echo "= Using existing config file ="
    echo "=========================="
  fi
}

build_dbs () {
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
    valhalla_build_timezones > ${timezone_db}
  else
    echo "=========================="
  fi
}

# Check for custom file folder and create if it doesn't exist.
if ! test -d "${custom_folder}"; then
  mkdir -p ${custom_folder}
fi

# Same for hashes file
if ! test -f "${hash_file}"; then
  touch ${hash_file}
fi

# Create build folder if they don't exist
dirs="timezone_data admin_data elevation_data"
for d in $dirs; do
  if ! test -d $custom_folder/$d; then
    mkdir $custom_folder/$d
  fi
done

# Check if valhalla_tiles.tar exists
if test -f "${tile_extract}" || test -d "${tile_dir}"; then
  echo "Found valhalla tiles with use_tiles_ignore_pbf: ${use_tiles_ignore_pbf}!"
  if [[ ${use_tiles_ignore_pbf} == "True" ]]; then
    echo "Jumping directly to the tile loading!"
    build_config
    build_dbs
    exit 0
  fi
else
  echo "Valhalla tiles not found!"
  do_build="True"
fi

# Find and add .pbf files to the list of files
for file in $(ls $custom_folder/*.pbf); do
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
  rm -rf "${tile_dir}"
  rm -rf "${tile_extract}"
  rm -rf "${hash_file}"
  echo "PBF file Counter: $files_counter"
  do_build="True"
fi

if test -f "${tile_extract}" || test -d "${tile_dir}"; then 
  if [[ ${do_build} == "False" && ${hashes} == ${files_counter} ]]; then
    echo "All files have already been built and valhalla tiles exist. Starting without new build!"
    echo "PBF hashes: $hashes"
    echo "PBF file Counter: $files_counter"
    echo "Found valhalla tiles!"
    build_config
    build_dbs
    exit 0
  else
    echo "New files were detected, rebuilding files: ${files}"
    do_build="True"
  fi
else
  echo "Either valhalla_tiles.tar couldn't be found or new files or file constellations were detected. Rebuilding files: ${files}"
  echo "PBF hashes: $hashes"
  echo "PBF file Counter: $files_counter"
  do_build="True"
fi

if [[ ${files_counter} == 0 ]] && [[ ${do_build} == "True" ]]; then
  if [[ -z "${tile_urls}" ]]; then
    echo "No local PBF files, valhalla_tiles.tar and no tile URLs found. Nothing to do."
    exit 1
  else
    echo "No local files and no valhalla_tiles.tar found. Downloading links: ${tile_urls}!"
    download_files "${tile_urls}"
  fi
fi

if [[ ${files_counter} == 0 ]]; then
  # Find and add .pbf files to the list of files that were just downloaded
  for file in $(ls $custom_folder/*.pbf); do
    echo "${file}"
    if [[ ! $(hash_exists ${file}) == "True" ]]; then
      echo "Hash not found for: ${file}!"
    else
      echo "Hash found for: ${file}"
    fi
    files="${files} ${file}"
    files_counter=$((files_counter + 1))
  done
fi

build_config
build_dbs

# Finally build the tiles
if [[ ${build_elevation} == "True" || ${build_elevation} == "Force" ]]; then
  if [[ ${build_elevation} == "Force" && -d $elevation_path ]]; then
    echo "Rebuilding elevation tiles"
    rm -rf $elevation_path
  fi

  # if we should build with elevation we need to build the tiles in stages

  echo ""
  echo "========================="
  echo "= Build the initial graph. ="
  echo "========================="

  valhalla_build_tiles -c ${config_file} -e build ${files} || exit 1

  # Build the elevation data
  echo ""
  echo "================================="
  echo "= Download the elevation tiles ="
  echo "================================="
  valhalla_build_elevation --from-tiles --decompress -c $config_file || exit 1

  echo ""
  echo "======================================"
  echo "= Enhancing the graph with elevation ="
  echo "======================================"
  valhalla_build_tiles -c ${config_file} -s enhance ${files} || exit 1
else
  echo ""
  echo "========================="
  echo "= Build the tile files. ="
  echo "========================="
  echo "Running build tiles with: ${config_file} ${files}"

  valhalla_build_tiles -c ${config_file} ${files} || exit 1
fi

echo "Successfully built files: ${files}"
add_hashes "${files}"
