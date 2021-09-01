#!/usr/bin/env bash

# Create different extracts with osmium based on an osmium config file

. /valhalla/scripts/env.sh

CITY_REPO="canada_cities_osmium_extract"

printf "### Installing Osmium & Git ###\n"

# install or update osmium & git if not installed already
apt-get update -y  && apt-get install -y osmium-tool git wget

git clone https://github.com/gis-ops/canada_cities_osmium_extract.git ${SCRIPTS_PATH}/extras/${CITY_REPO}

printf "\n### Downloading OSM extracts ###\n"

for extract in us-midwest us-northeast us-south canada
do
  fp=${CUSTOM_FILES}/${extract}-latest.osm.pbf
  if [[ ! -f "${fp}" ]]; then
    echo "Downloading to ${fp}"
    wget http://download.geofabrik.de/north-america/${extract}-latest.osm.pbf -P ${CUSTOM_FILES} --quiet
  else
    echo "${fp} already exists."
  fi
done

printf "\n### Cutting regions ###\n"

osmium extract --config ${SCRIPTS_PATH}/extras/${CITY_REPO}/osmium_extract_config.json --set-bounds ${CUSTOM_FILES}/canada-latest.osm.pbf

printf "\n### Downloading elevation ###\n"
