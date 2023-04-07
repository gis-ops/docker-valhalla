[![ci tests](https://github.com/gis-ops/docker-valhalla/actions/workflows/tests.yml/badge.svg)](https://github.com/gis-ops/docker-valhalla/actions/workflows/tests.yml)

# Valhalla Docker image by GIS • OPS

A hyper-flexible Docker image for the excellent [Valhalla](https://github.com/valhalla/valhalla) routing framework.

```bash
# download a file to custom_files and start valhalla
mkdir custom_files
wget -O custom_files/andorra-latest.osm.pbf https://download.geofabrik.de/europe/andorra-latest.osm.pbf
docker run -dt --name valhalla_gis-ops -p 8002:8002 -v $PWD/custom_files:/custom_files ghcr.io/gis-ops/docker-valhalla/valhalla:latest
# or let the container download the file for you
docker run -dt --name valhalla_gis-ops -p 8002:8002 -v $PWD/custom_files:/custom_files -e tile_urls=https://download.geofabrik.de/europe/andorra-latest.osm.pbf ghcr.io/gis-ops/docker-valhalla/valhalla:latest
```

This image aims at being user-friendly and most efficient with your time and resources. Once built, you can easily change Valhalla's configuration, the underlying OSM data graphs are built from, accompanying data (like Admin Areas, elevation tiles) or even pre-built graph tiles. Upon `docker restart <container>` those changes are taken into account via **hashed files**, and, if necessary, new graph tiles will be built automatically.

## Features

-   Easily switch graphs by mapping different volumes to containers.
-   Stores all relevant data (tiles, config, admin & timezone DBs, elevation) in the mapped volume.
-   Load and build from **multiple URLs** pointing to valid pbf files.
-   Load local data through volume mapping.
-   **Supports auto rebuild** on OSM file changes through hash mapping.
- 	**new**: supports advanced user management to avoid sudo access to host-shared folders and files, see [notes on user management](#notes-on-user-management)

## Dockerhub/Github Packages

**NOTE**, with the recent (17.03.2023) announcement of Docker to remove free "teams" (even those providing FOSS like us), we moved our images to Github packages. If it's not on Github you'll find an image version still on Dockerhub.

Our [package registry](https://github.com/gis-ops/docker-valhalla/pkgs/container/docker-valhalla%2Fvalhalla) provides the following:

- stable release tags (e.g. 3.0.9)
- `latest`, updated from Valhalla Github repository every Saturday morning

> Note, you might have to do a [`docker login`](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-docker-registry#authenticating-to-github-packages) before.

## Build the image

If you want to build the image yourself, be aware that you might need to adapt the base image in the `Dockerfile` to reflect the version of Valhalla you'd like to build. You can find the tags of the `ghcr.io/valhalla/valhalla` images here: https://github.com/valhalla/valhalla/pkgs/container/valhalla. On top of the Valhalla base image we support the following build arguments (see [notes on user management](#notes-on-user-management)):

- `VALHALLA_UID`: specify the user UID for the container-internal `valhalla` user. Either leave this blank or, most usually, specify your current user's UID.
- `VALHALLA_GID`: specify the group GID for the container-internal `valhalla` user. Either leave this blank or, most usually, specify the group's GID whose members you want to have write access to the container-generated files.

**Note**, before Valhalla version `3.1.0` the building scheme was completely different. Please contact enquiry@gis-ops.com if you need access to previous Valhalla versions via Docker.

Then it's a simple

```shell script
docker build -t ghcr.io/gis-ops/docker-valhalla/valhalla:latest .
```

## Environment variables

This image respects the following custom environment variables to be passed during container startup. Note, all variables have a default:

- `tile_urls`: Add as many (space-separated) URLs as you like, e.g. https://download.geofabrik.de/europe/andorra-latest.osm.pbf
- `use_tiles_ignore_pbf`: `True` uses a local tile.tar file and skips building. Default `False`.
- `force_rebuild`: `True` forces a rebuild of the routing tiles. Default `False`.
- `build_elevation`: `True` downloads elevation tiles which are covering the routing graph. `Force` will do the same, but first delete any existing elevation tiles. Default `False`.
- `build_admins`: `True` builds the admin db needed for things like border-crossing penalties and detailed routing responses. `Force` will do the same, but first delete the existing db. Default `False`.
- `build_time_zones`: `True` builds the timezone db which is needed for time-dependent routing. `Force` will do the same, but first delete the existing db. Default `False`.
- `build_transit`: `True` will attempt to build transit tiles if none exist yet. `Force` will remove existing transit **and** routing tiles. Default `False`.
- `build_tar` (since 29.10.2021/v`3.1.5`): `True` creates a tarball of the tiles including an index which allows for extremely faster graph loading after reboots. `Force` will do the same, but first delete the existing tarball. Default `True`.
- `server_threads`: How many threads `valhalla_build_tiles` will use and `valhalla_service` will run with. Default is the value of `nproc`.
- `path_extension`: This path will be appended to the container-internal `/custom_files` (and by extension to the docker volume mapped to that path) and will be the directory where all files will be created. Can be very useful in certain deployment scenarios. No leading/trailing path separator allowed. Default is ''.
- `serve_tiles`: `True` starts the valhalla service. Default `True`.
- `tileset_name`: The name of the resulting graph on disk. Very useful in case you want to build multiple datasets in the same directory. Default `valhalla_tiles`.
- `traffic_name`: The name of the traffic.tar. Again, useful for serving mulitple traffic archives from the same directory. If empty, i.e. "", then no traffic archive will be built. Default `traffic.tar`.

## Container recipes

For the following instructions to work, you'll need to have the image locally available already, either from [Github Docker registry](https://github.com/gis-ops/docker-valhalla/pkgs/container/docker-valhalla%2Fvalhalla) or from [local](#build-the-image).

Start a background container from that image:

```bash
docker run -dt -v $PWD/custom_files:/custom_files -p 8002:8002 --name valhalla ghcr.io/gis-ops/docker-valhalla/valhalla:latest
```

The important part here is, that you map a volume from your host machine to the container's **`/custom_files`**. The container will dump all relevant Valhalla files to that directory.

At this point Valhalla is running, but there is no graph tiles yet. Follow the steps below to customize your Valhalla instance in a heartbeat.

> Note, alternatively you could create `custom_files` on your host before starting the container with all necessary files you want to be respected, e.g. the OSM PBF files.

#### Build Valhalla with transit

Valhalla supports reading raw GTFS feeds to build transit into its graph, see the [docs](https://valhalla.github.io/valhalla/api/turn-by-turn/api-reference/#sample-json-payloads-for-multimodal-requests-with-transit) for more details.

To enable `multimodal` routing, you'll need to map the directory which contains all the GTFS feeds to the container's `/gtfs_feeds` directory, e.g.

```
docker run -dt -v gtfs_feeds:/gtfs_feeds -v $PWD/custom_files:/custom_files -p 8002:8002 --name valhalla gisops/valhalla:latest
```

#### Build Valhalla with arbitrary OSM data

Just dump **single or multiple** OSM PBF files to your mapped `custom_files` directory, restart the container and Valhalla will start building the graphs:

```bash
cd custom_files
# Download Andorra & Faroe Islands
wget http://download.geofabrik.de/europe/faroe-islands-latest.osm.pbf http://download.geofabrik.de/europe/andorra-latest.osm.pbf
docker restart valhalla
```

If you change the PBF files by either adding new ones or deleting any, Valhalla will build new tiles on the next restart unless told not to (e.g. setting `use_tiles_ignore_pbf=True`).

#### Customize Valhalla configuration

If you need to customize Valhalla's configuration to e.g. increase the allowed maximum distance for the `/route` POST endpoint, just edit `custom_files/valhalla.json` and restart the container. It won't rebuild the tiles in this case, unless you tell it to do so via environment variables.

#### Run Valhalla with pre-built tiles

In the case where you have a pre-built `valhalla_tiles.tar` package from another Valhalla instance, you can also dump that to `/custom_files/` and they're loaded upon container restart if you set the following environment variables: `use_tiles_ignore_pbf=True`, `force_rebuild=False`. Also, don't forget to set the md5 sum for your `valhalla_tiles.tar` in `.file_hashes.txt`.

## Tests

If you want to verify that the image is working correctly, there's a small test script in `./tests`. **Note**, it might require `sudo`, since it touches a few things generated by the container's `valhalla` user:

```shell script
./tests/test.sh
```

## Acknowledgements

This project was first introduced by [MichaelsJP](https://github.com/MichaelsJP).
