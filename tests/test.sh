set -u

# keep requesting a route until it succeeds
wait_for_docker() {
  while true; do
    eval $route_request > /dev/null
    if [[ 0 -eq $? ]]; then
     return
    fi
    sleep 1
  done
}

custom_file_folder="$PWD/custom_files"
admin_db="${custom_file_folder}/admin_data/admins.sqlite"
timezone_db="${custom_file_folder}/timezone_data/timezones.sqlite"
elevation_path="${custom_file_folder}/elevation_data"
tile_tar="${custom_file_folder}/valhalla_tiles.tar"

route_request="curl -s -XPOST 'http://localhost:8002/route' -H'Content-Type: application/json' --data-raw '{
    \"locations\": [
        {
            \"lat\": 42.546504,
            \"lon\": 1.591129
        },
        {
            \"lat\": 42.507667,
            \"lon\": 1.542721
        }
    ],
    \"costing\": \"auto\"
}'"

# Get Andorra to test with
if ! test -d "${custom_file_folder}"; then
  mkdir -p ${custom_file_folder}
fi
if ! test -f "$custom_file_folder/andorra-latest.osm.pbf"; then
  wget http://download.geofabrik.de/europe/andorra-latest.osm.pbf -O "$custom_file_folder/andorra-latest.osm.pbf"
fi

#### FULL BUILD ####
echo "#### Full build test ####"
docker run -d --name valhalla_full -p 8002:8002 -v $custom_file_folder:/custom_files -e use_tiles_ignore_pbf=False -e build_elevation=True -e build_admins=True -e build_time_zones=True -e min_x=1.409683 -e min_y=42.423963 -e max_x=1.799011 -e max_y=42.661736 gisops/valhalla:latest
wait_for_docker

# Make sure all files are there!
for f in ${admin_db} ${timezone_db}; do
  if [[ ! -f $f ]]; then
    echo "Couldn't find ${f}"
    exit 1
  fi
done
if [[ ! $(ls ${elevation_path}) ]]; then
  echo "Empty elevation dir"
  exit 1
fi

eval $route_request > /dev/null

# Save the modification dates
mod_date_tiles=$(stat -c %y ${tile_tar})
mod_date_admins=$(stat -c %y ${admin_db})
mod_date_timezones=$(stat -c %y ${timezone_db})


#### Change the config dynamically ####
echo "#### Change config test ####"
jq '.service_limits.auto.max_distance = 5.0' "${custom_file_folder}/valhalla.json" | sponge "${custom_file_folder}/valhalla.json"

docker restart valhalla_full
wait_for_docker

# response has error code 154 (max distance exceeded)
res=$(eval $route_request | jq '.error_code')

if [[ $res != "154" ]]; then
  echo "This is the response:"
  echo "$(eval $route_request)"
  exit 1
fi

# Tiles weren't modified
if [[ $(stat -c %y ${tile_tar}) != $mod_date_tiles ]]; then
  echo "valhalla_tiles.tar was modified even though it shouldn't"
  exit 1
fi

#### Add a PBF, restart and see if it worked ####
echo "#### Add PBF test ####"
# reset the config
rm ${custom_file_folder}/valhalla.json
if ! test -f "$custom_file_folder/liechtenstein-latest.osm.pbf"; then
  wget http://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf -O "$custom_file_folder/liechtenstein-latest.osm.pbf"
fi

docker restart valhalla_full
wait_for_docker

eval $route_request 2>&1 > /dev/null
# Tiles WERE modified
if [[ $(stat -c %y ${tile_tar}) == $mod_date_tiles ]]; then
  echo "valhalla_tiles.tar was NOT modified even though it should've"
  exit 1
fi
mod_date_tiles2=$(stat -c %y ${tile_tar})


#### Create a new container with same config ####
docker rm -f valhalla_full
docker run -d --name valhalla_repeat -p 8002:8002 -v $custom_file_folder:/custom_files -e use_tiles_ignore_pbf=True -e build_elevation=True -e build_admins=True -e build_time_zones=True -e min_x=1.409683 -e min_y=42.423963 -e max_x=1.799011 -e max_y=42.661736 gisops/valhalla:latest
wait_for_docker

# Tiles, admins & timezones weren't modified
if [[ $(stat -c %y ${tile_tar}) != $mod_date_tiles2 || $(stat -c %y ${admin_db}) != $mod_date_admins || $(stat -c %y ${timezone_db}) != $mod_date_timezones ]]; then
  echo "some data was modified even though it shouldn't have"
  exit 1
fi

docker rm -f valhalla_repeat

echo "Final structure:"
tree -L2 "${custom_file_folder}"

exit 0
