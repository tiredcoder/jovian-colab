#!/usr/bin/sh
SCRIPT_DIR=$(dirname "$0")
DOCKER_IMAGE="python:3-alpine"

echo " *** Building ipfs-client module using $DOCKER_IMAGE Docker container... *** "
rm -rf "$SCRIPT_DIR/dist"
mkdir "$SCRIPT_DIR/dist"
CONTAINER="ipfs-client-builder"
docker run -d -t --name "$CONTAINER" -v "$(readlink -f ${SCRIPT_DIR}):/mnt/app" -w /mnt/app "$DOCKER_IMAGE"
docker exec -it --user=root "$CONTAINER" sh -c 'python3 -m pip install build'
docker exec -it --user=$(id -u):$(id -g) "$CONTAINER" sh -c 'python3 -m build .'
docker kill "$CONTAINER" && docker rm "$CONTAINER"
