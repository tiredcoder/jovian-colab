#!/usr/bin/sh
SCRIPT_DIR=$(dirname "$0")
DOCKER_IMAGE="node:14.18.3-alpine"

echo " *** Building fabric-gw-client module using $DOCKER_IMAGE Docker container... *** "
rm -rf "$SCRIPT_DIR/dist"
mkdir "$SCRIPT_DIR/dist" "$SCRIPT_DIR/node_modules" "$SCRIPT_DIR/lib"
CONTAINER="fabric-gw-client-builder"
docker run -d -t --name "$CONTAINER" -v "$(readlink -f ${SCRIPT_DIR}):/mnt/app" -w /mnt/app "$DOCKER_IMAGE"
docker exec -it --user=root "$CONTAINER" sh -c 'apk add --update python3 make g++ && npm install -g npm@latest'
docker exec -it --user="$(id -u)" "$CONTAINER" sh -c 'npm install && npm run build && yarn pack -f ./dist/fabric-gw-client.tgz'
docker kill "$CONTAINER" && docker rm "$CONTAINER"
