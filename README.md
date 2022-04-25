[![ci tests](https://github.com/gis-ops/docker-valhalla/actions/workflows/tests.yml/badge.svg)](https://github.com/gis-ops/docker-valhalla/actions/workflows/tests.yml)

# Valhalla Docker image by GIS • OPS

A hyper-flexible Docker image for the excellent [Valhalla](https://github.com/valhalla/valhalla) routing framework.

```bash
# download a file to custom_files and start valhalla
mkdir custom_files
wget -O custom_files/andorra-latest.osm.pbf https://download.geofabrik.de/europe/andorra-latest.osm.pbf
docker run -dt --name valhalla_gis-ops -p 8002:8002 -v $PWD/custom_files:/custom_files gisops/valhalla:latest
# or let the container download the file for you
docker run -dt --name valhalla_gis-ops -p 8002:8002 -v $PWD/custom_files:/custom_files -e tile_urls=https://download.geofabrik.de/europe/andorra-latest.osm.pbf gisops/valhalla:latest
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

**NOTE**, with the recent (08.06.2021) announcement of Docker to close auto-builds, we're moving our images to Github packages. If it's not on Github you'll find an image version still on Dockerhub.

~~In the [Dockerhub repository](https://hub.docker.com/r/gisops/valhalla) you'll find the following images/tags:~~

~~- stable release tags (e.g. 3.0.9)~~
~~- `latest`, updated from Valhalla Github repository every Saturday morning~~

Find the Docker images in our [package registry](https://github.com/orgs/gis-ops/packages?repo_name=docker-valhalla). The general syntax to pull an image from Github is `docker pull docker.pkg.github.com/gis-ops/docker-valhalla/valhalla:latest` (you might have to do a [`docker login`](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-docker-registry#authenticating-to-github-packages) before).

## Build the image

If you want to build the image yourself, be aware that you might need to adapt the base image in the `Dockerfile` to reflect the version of Valhalla you'd like to build. You can find the tags of the `valhalla/valhalla:run-*` images here: https://hub.docker.com/r/valhalla/valhalla/tags. On top of the Valhalla base image we support the following build arguments (see [notes on user management](#notes-on-user-management)):

- `VALHALLA_UID`: specify the user UID for the container-internal `valhalla` user. Either leave this blank or, most usually, specify your current user's UID.
- `VALHALLA_GID`: specify the group GID for the container-internal `valhalla` user. Either leave this blank or, most usually, specify the group's GID whose members you want to have write access to the container-generated files.

**Note**, before Valhalla version `3.1.0` the building scheme was completely different. Please contact enquiry@gis-ops.com if you need access to previous Valhalla versions via Docker.

Then it's a simple

```shell script
docker build -t gisops/valhalla .
```

## Environment variables

This image respects the following custom environment variables to be passed during container startup. Note, all variables have a default:

- `tile_urls`: Add as many (space-separated) URLs as you like, e.g. https://download.geofabrik.de/europe/andorra-latest.osm.pbf 
- `use_tiles_ignore_pbf`: `True` uses a local tile.tar file and skips building. Default `False`.
- `force_rebuild`: `True` forces a rebuild of the routing tiles. Default `False`.
- `build_elevation`: `True` downloads elevation tiles which are covering the routing graph. `Force` will do the same, but first delete any existing elevation tiles. Default `False`.
- `build_admins`: `True` builds the admin db needed for things like border-crossing penalties and detailed routing responses. `Force` will do the same, but first delete the existing db. Default `False`.
- `build_time_zones`: `True` builds the timezone db which is needed for time-dependent routing. `Force` will do the same, but first delete the existing db. Default `False`.
- `build_tar` (since 29.10.2021/v`3.1.5`): `True` creates a tarball of the tiles including an index which allows for extremely faster graph loading after reboots. `Force` will do the same, but first delete the existing tarball. Default `True`.
- `server_threads`: How many threads `valhalla_service` will run with. Default is the value of `nproc`.
- `path_extension`: This path will be appended to the container-internal `/custom_files` (and by extension to the docker volume mapped to that path) and will be the directory where all files will be created. Can be very useful in certain deployment scenarios. No leading/trailing path separator allowed. Default is ''.
- `serve_tiles`: `True` starts the valhalla service. Default `True`.

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

In the case where you have a pre-built `valhalla_tiles.tar` package from another Valhalla instance, you can also dump that to `/custom_files/` and they're loaded upon container restart if you set the following environment variables: `use_tiles_ignore_pbf=True`, `force_rebuild=False`. Also, don't forget to set the md5 sum for your `valhalla_tiles.tar` in `.file_hashes.txt`.

## Notes on user management

Since 18.11.2021 the `latest` image (and supposedly the `3.1.5` tagged image) supports advanced user management. During the build one can pass `VALHALLA_UID` and `VALHALLA_GID` as build arguments. These will be used to create the container-internal user `valhalla`. Practically, this means if you build the image with your current user's UID & GID (usually 1000 if you're the only Linux user) you (or the users of `VALHALLA_GID`) can edit all the files and folders which the Valhalla container creates in the volume you share (the config file, routing tiles etc.).

By default the images published on Dockerhub and Github Packages, and the Dockerfile, have the `VALHALLA_UID` & `VALHALLA_GID` of 0. In that mode the `valhalla` user will run as `sudo` so all files & folders will be owned by `root`.

On a side note, this finally eliminates some security concerns and puts a user in a much more flexible position. Though running a Valhalla container as root internally and exposing a host-shared volume is normally not a problem as Valhalla itself has very little attack surface. Still..

## Tests

If you want to verify that the image is working correctly, there's a small test script in `./tests`. **Note**, it might require `sudo`, since it touches a few things generated by the container's `valhalla` user, see the [notes on user management](#notes-on-user-management):

```shell script
./tests/test.sh
```

## Acknowledgements

This project was first introduced by [MichaelsJP](https://github.com/MichaelsJP).
