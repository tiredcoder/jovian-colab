#!/usr/bin/sh
SCRIPT_DIR=$(dirname "$0")
DOCKER_IMAGE="node:16-alpine"
DOCKER_NETWORK='jovian-colab_demo-net'
FABRIC_CRYPTO="$(readlink -f ../../../docker/fabric/fabric-config/crypto-config)"
FABRIC_PROFILES="$(readlink -f ../../../docker/fabric/fabric-config/connection-profiles)"
CONTAINER="fabric-acl-policy-tester"

echo " *** Running ACL policy test app using $DOCKER_IMAGE Docker container... *** "
mkdir "$SCRIPT_DIR/node_modules" "$SCRIPT_DIR/wallet"

docker run -d -t --name "$CONTAINER" --network "$DOCKER_NETWORK" -v "$(readlink -f ${SCRIPT_DIR}):/mnt/app" -v "${FABRIC_CRYPTO}:/mnt/crypto-config:ro" -v "${FABRIC_PROFILES}:/mnt/fabric-profiles:ro" -w /mnt/app "$DOCKER_IMAGE"
docker exec -it --user=root "$CONTAINER" sh -c "npm install -g npm@latest && deluser --remove-home node && addgroup -S node -g $(id -g) && adduser -S -G node -u $(id -u) node"
docker exec -it --user=node "$CONTAINER" sh -c 'npm install'

echo -e "\n\nReady! Starting interactive shell in container.\nPlease add the user's credentials to the wallet and then run 'testPolicy.js'\n"
docker exec -it --user=node "$CONTAINER" sh

docker kill "$CONTAINER" && docker rm "$CONTAINER"
