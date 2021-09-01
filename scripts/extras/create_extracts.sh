#!/usr/bin/env bash

# Create different extracts with osmium based on an osmium config file

. /valhalla/scripts/runtime/env.sh

CITY_REPO="canada_cities_osmium_extract"

printf "--- Installing Osmium & Git---\n"

# install or update osmium & git if not installed already
apt-get update -y > /dev/null && apt-get install -y osmium-tool git > /dev/null

git clone https://github.com/gis-ops/canada_cities_osmium_extract.git ${SCRIPTS_PATH}/${CITY_REPO}

printf "\n--- Downloading OSM extracts ---\n"

for extract in us-midwest us-northeast us-south canada
do
  fp=${CUSTOM_FILES}/${extract}-latest.osm.pbf
  if [[ ! -f "$fp" ]]; then
    echo "Downloading to ${fp}"
    wget http://download.geofabrik.de/north-america/${extract}-latest.osm.pbf -o ${fp} > /dev/null
  fi
done

printf "\n--- Cutting regions ---\n"

osmmium extract --set-bounds --config ${SCRIPTS_PATH}/${CITY_REPO}/osmium_extract_config.json

printf "\n--- Downloading elevation ---\n"
