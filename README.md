[![ci tests](https://github.com/gis-ops/docker-valhalla/actions/workflows/tests.yml/badge.svg)](https://github.com/gis-ops/docker-valhalla/actions/workflows/tests.yml)

# Valhalla Docker image by GIS • OPS

A hyper-flexible Docker image for the excellent [Valhalla](https://github.com/valhalla/valhalla) routing framework.

```bash
docker run -dt --name valhalla_gis-ops -p 8002:8002 -v $PWD/custom_files:/custom_files gisops/valhalla:latest
```

This image aims at being user-friendly and most efficient with your time and resources. Once built, you can easily change Valhalla's configuration, the underlying OSM data graphs are built from, accompanying data (like Admin Areas, elevation tiles) or even pre-built graph tiles. Upon `docker restart <container>` those changes are taken into account via **hashed files**, and, if necessary, new graph tiles will be built automatically.

## Features

-   Easily switch graphs by mapping different volumes to containers.
-   Stores all relevant data (tiles, config, admin & timezone DBs, elevation) in the mapped volume.
-   Load and build from **multiple URLs** pointing to valid pbf files.
-   Load local data through volume mapping.
-   **Supports auto rebuild** on OSM file changes through hash mapping.

## Dockerhub/Github Packages

**NOTE**, with the recent (08.06.2021) announcement of Docker to close auto-builds, we're moving our images to Github packages. If it's not on Github you'll find an image version still on Dockerhub.

~~In the [Dockerhub repository](https://hub.docker.com/r/gisops/valhalla) you'll find the following images/tags:~~

~~- stable release tags (e.g. 3.0.9)~~
~~- `latest`, updated from Valhalla Github repository every Saturday morning~~

Find the Docker images in our [package registry](https://github.com/orgs/gis-ops/packages?repo_name=docker-valhalla). The general syntax to pull an image from Github is `docker pull docker.pkg.github.com/gis-ops/docker-valhalla/valhalla:latest` (you might have to do a [`docker login`](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-docker-registry#authenticating-to-github-packages) before).

## Build the image

If you want to build the image yourself, be aware that you might need to adapt the base image in the `Dockerfile` to reflect the version of Valhalla you'd like to build. You can find the tags of the `valhalla/valhalla:run-*` images here: https://hub.docker.com/r/valhalla/valhalla/tags.

**Note**, that this is only valid down to `3.1.0`, before the building scheme was completely different. Please contact enquiry@gis-ops.com if you need access to previous Valhalla versions via Docker.

Then it's a simple

```shell script
docker build -t gisops/valhalla .
```

## Environment variables

This image respects the following custom environment variables to be passed during container startup. Note, all variables have a default:

- `tile_urls`: Add as many (space-separated) URLs as you like, e.g. https://download.geofabrik.de/europe/andorra-latest.osm.pbf http://download.geofabrik.de/europe/faroe-islands-latest.osm.pbf. Default `""`.
- `min_x`: Minimum longitude for elevation tiles, in decimal WGS84, e.g. 18.5
- `min_y`: Minimum latitude for elevation tiles, in decimal WGS84, e.g. 18.5
- `max_x`: Maximum longitude for elevation tiles, in decimal WGS84, e.g. 18.5
- `max_y`: Maximum latitude for elevation tiles, in decimal WGS84, e.g. 18.5
- `use_tiles_ignore_pbf`: `True` uses a local tile.tar file and skips building. Default `False`.
- `force_rebuild`: `True` forces a rebuild of the routing tiles. Default `False`.
- `build_elevation`: `True` downloads elevation tiles for the set bounding box. `Force` will do the same, but first delete any existing elevation tiles. Default `False`.
- `build_admins`: `True` builds the admin db. `Force` will do the same, but first delete the existing db. Default `False`.
- `build_time_zones`: `True` builds the timezone db. `Force` will do the same, but first delete the existing db. Default `False`.
- `build_tar` (since `3.1.4`): `True` creates a tarball of the tiles. `Force` will do the same, but first delete the existing tarball. Default `True`.
- `server_threads`: How many threads `valhalla_service` will run with. Default is 1 thread less than the value of `nproc`.

## Container recipes

For the following instructions to work, you'll need to have the image locally available already, either from [Docker Hub](https://hub.docker.com/repository/docker/gisops/valhalla) or from [local](#build-the-image).

Start a background container from that image:

```bash
docker run -dt -v $PWD/custom_files:/custom_files -p 8002:8002 --name valhalla gisops/valhalla:latest
```

The important part here is, that you map a volume from your host machine to the container's **`/custom_files`**. The container will dump all relevant Valhalla files to that directory.

At this point Valhalla is running, but there is no graph tiles yet. Follow the steps below to customize your Valhalla instance in a heartbeat.

> Note, alternatively you could create `custom_files` on your host before starting the container with all necessary files you want to be respected, e.g. the OSM PBF files.

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

In the case where you have a pre-built `valhalla_tiles.tar` package from another Valhalla instance, you can also dump that to `custom_files/` and they're loaded upon container restart if you set the following environment variables: `use_tiles_ignore_pbf=True`, `force_rebuild=False`. Also, don't forget to set the md5 sum for your `valhalla_tiles.tar` in `.file_hashes.txt`.

## Tests

If you want to verify that the image is working correctly, there's a small test script in `./tests`. **Note**, it requires `sudo` since it touches a few things generated by the container's `root` user (no worries, it won't break your system):

```shell script
sudo ./tests/test.sh
```

## Acknowledgements

This project was first introduced by [MichaelsJP](https://github.com/MichaelsJP).
