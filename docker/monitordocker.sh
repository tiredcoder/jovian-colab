#!/bin/bash

# This script uses the logspout and http stream tools to let you watch the docker containers in action.
#
# More information at https://github.com/gliderlabs/logspout/tree/master/httpstream

# Import variables from .env file (DEMO_NETWORK_NAME)
set -o allexport
source ./fabric/fabric-docker/.env
set +o allexport

# Parse script args
if [ -z "$1" ]; then
   DOCKER_NETWORK="$DEMO_NETWORK_NAME"
else
   DOCKER_NETWORK="$1"
fi

if [ -z "$2" ]; then
   PORT=8000
else
   PORT="$2"
fi

if [ -z "$3" ]; then
   CONTAINER_NAME="jc_demo_logspout"
else
   CONTAINER_NAME="$3"
fi

# Start logspout container
echo "Starting monitoring on all containers on the network ${DOCKER_NETWORK}"

docker kill "${CONTAINER_NAME}" 2> /dev/null 1>&2 || true
docker rm "${CONTAINER_NAME}" 2> /dev/null 1>&2 || true

docker run -d --name="${CONTAINER_NAME}" \
	--volume=/var/run/docker.sock:/var/run/docker.sock \
	--publish=127.0.0.1:${PORT}:80 \
	--network ${DOCKER_NETWORK} \
	gliderlabs/logspout

# Get output
sleep 4
curl http://127.0.0.1:${PORT}/logs
