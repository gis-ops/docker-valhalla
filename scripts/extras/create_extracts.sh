#!/usr/bin/env bash

# Create different extracts with osmium based on an osmium config file

. /valhalla/scripts/env.sh

CITY_REPO="canada_cities_osmium_extract"
EXTRACT_REPO="elevation_tiles_from_polygons"

cd ${SCRIPTS_PATH}/extras

printf "### Installing Osmium & Git ###\n"

# install or update osmium & git if not installed already
apt-get update -y  && apt-get install -y osmium-tool git wget python3-pip python3.8-venv

git clone https://github.com/gis-ops/canada_cities_osmium_extract.git ${CITY_REPO} || git -C ${CITY_REPO} pull
git clone https://github.com/gis-ops/elevation_tiles_from_polygons.git ${EXTRACT_REPO} || git -C ${CITY_REPO} pull

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

osmium extract --config ${CITY_REPO}/osmium_extract_config.json --set-bounds ${CUSTOM_FILES}/canada-latest.osm.pbf || true

printf "\n### Downloading elevation ###\n"

cd  ${EXTRACT_REPO}

if [[ -d .venv ]]; then
  python -m venv .venv
fi
. .venv/bin/activate
pip install -r requirements.txt

python -m build_elevation ../${CITY_REPO}/inputs ${CUSTOM_FILES}/elevation_data -v

printf "\n### Finished successfully. ###\n"
