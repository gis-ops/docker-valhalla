set -u

valhalla_image=$1

custom_file_folder="$PWD/tests/custom_files"
admin_db="${custom_file_folder}/admin_data/admins.sqlite"
timezone_db="${custom_file_folder}/timezone_data/timezones.sqlite"
ANDORRA="$PWD/tests/andorra-latest.osm.pbf"
LIECHTENSTEIN="$PWD/tests/liechtenstein-latest.osm.pbf"

# keep requesting a route until it succeeds
wait_for_docker() {
  count=0
  max=60
  while ! [[ $count == $max ]]; do
    eval $route_request > /dev/null
    if [[ 0 -eq $? ]]; then
     return
    fi
    sleep 1
    count=$(($count + 1))
    echo "Tried $count times"
  done

  echo "max count reached"
  docker logs --tail 50 valhalla_full
  exit 1
}

last_mod_tiles() {
  find "${custom_file_folder}/$1" -type f -exec stat \{\} --printf="%y\n" \; | sort -nr | head -n 1
}

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
if ! test -f "${ANDORRA}"; then
  wget http://download.geofabrik.de/europe/andorra-latest.osm.pbf -O ${ANDORRA}
fi
cp ${ANDORRA} ${custom_file_folder}

#### FULL BUILD ####
echo "#### Full build test, no extract ####"
tileset_name="andorra_tiles"
tile_tar="${custom_file_folder}/${tileset_name}.tar"
docker run -d --name valhalla_full -p 8002:8002 -v $custom_file_folder:/custom_files -e tileset_name=$tileset_name -e use_tiles_ignore_pbf=False -e build_elevation=False -e build_admins=True -e build_time_zones=True -e build_tar=False -e server_threads=1 ${valhalla_image}
wait_for_docker

# Make sure all files are there!
for f in ${admin_db} ${timezone_db}; do
  if [[ ! -f $f ]]; then
    echo "Couldn't find ${f}"
    exit 1
  fi
done

eval $route_request > /dev/null

# Save the modification dates
mod_date_tiles=$(last_mod_tiles $tileset_name)
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
if [[ $(last_mod_tiles $tileset_name) != $mod_date_tiles ]]; then
  echo "new stat: $(last_mod_tiles $tileset_name), old stat: ${mod_date_tiles}"
  echo "valhalla_tiles were modified even though it shouldn't"
  exit 1
fi

#### Add a PBF, restart and see if it worked ####
echo "#### Add PBF test ####"
# reset the config
rm ${custom_file_folder}/valhalla.json
if ! test -f "${LIECHTENSTEIN}"; then
  wget http://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf -O "${LIECHTENSTEIN}"
fi
cp "${LIECHTENSTEIN}" "${custom_file_folder}"

docker restart valhalla_full
wait_for_docker

eval $route_request 2>&1 > /dev/null
# Tiles WERE modified
if [[ $(last_mod_tiles $tileset_name) == $mod_date_tiles ]]; then
  echo "valhalla_tiles.tar was NOT modified even though it should've"
  exit 1
fi
mod_date_tiles2=$(last_mod_tiles $tileset_name)

#### Create a tar ball ####
echo "#### Create tar ball only ####"

docker run --rm --name valhalla_tar -v ${custom_file_folder}:/custom_files -e tileset_name=$tileset_name ${valhalla_image} tar_tiles
if [[ ! -f "${custom_file_folder}/${tileset_name}.tar" ]]; then
  echo "tar_tiles CMD didn't work"
  exit 1
else
  rm "${custom_file_folder}/${tileset_name}.tar"
fi

#### Create a new container with same config ####
echo "#### New container but old data, also build the tar by default and check if it exists ####"
docker rm -f valhalla_full
docker run -d --name valhalla_repeat -p 8002:8002 -v $custom_file_folder:/custom_files -e tileset_name=$tileset_name -e use_tiles_ignore_pbf=True -e build_elevation=False -e build_admins=True -e build_time_zones=True -e server_threads=1 ${valhalla_image}
wait_for_docker

if [[ ! -f ${custom_file_folder}/${tileset_name}.tar ]]; then
  echo "default CMD didn't build the tar extract"
  exit 1
fi

# Tiles, admins & timezones weren't modified
if [[ $(last_mod_tiles $tileset_name) != $mod_date_tiles2 || $(stat -c %y ${admin_db}) != $mod_date_admins || $(stat -c %y ${timezone_db}) != $mod_date_timezones ]]; then
  echo "some data was modified even though it shouldn't have"
  exit 1
fi

echo "Final structure:"
tree -L 3 -h "${custom_file_folder}"

# cleanup
docker rm -f valhalla_repeat
rm -r ${custom_file_folder}

exit 0
