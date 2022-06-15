#!/usr/bin/env bash
set -e
MONITORING_NETWORK_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$MONITORING_NETWORK_ROOT/monitoring-docker/.env"

logspoutDown() {
  local CONTAINER_NAME="$1"
  docker kill "${CONTAINER_NAME}" 2> /dev/null 1>&2 || true
  docker rm "${CONTAINER_NAME}" 2> /dev/null 1>&2 || true
}

# logspout and http stream tools to let you watch the docker containers in action
# More information at https://github.com/gliderlabs/logspout/tree/master/httpstream
logspoutUp() {
  echo "Starting monitoring via logspout on all containers on the network ${DEMO_NETWORK_NAME}"
  
  # Get values from .env file
  local DOCKER_NETWORK="$DEMO_NETWORK_NAME"
  local SOCKET="$MONITORING_LOGSPOUT_SOCKET"
  local CONTAINER_NAME="$MONITORING_LOGSPOUT_CONTAINER_NAME"

  logspoutDown "$CONTAINER_NAME"

  docker run -d --name="${CONTAINER_NAME}" \
    --volume=/var/run/docker.sock:/var/run/docker.sock \
    --publish=${SOCKET}:80 \
    --network ${DOCKER_NETWORK} \
    gliderlabs/logspout

  # Get output
  sleep 4
  curl http://${SOCKET}/logs
}

networkUp() {
  echo "Starting monitoring network..."
  (cd "$MONITORING_NETWORK_ROOT"/monitoring-docker && docker-compose up -d)
}

startNetwork() {
  echo "Resuming monitoring network..."
  (cd "$MONITORING_NETWORK_ROOT"/monitoring-docker && docker-compose up -d)
}

stopNetwork() {
  echo "Stopping monitoring network..."
  (cd "$MONITORING_NETWORK_ROOT"/monitoring-docker && docker-compose stop)
}

networkDown() {
  echo "Destroying monitoring network..."
  (cd "$MONITORING_NETWORK_ROOT"/monitoring-docker && docker-compose down -v)
}

# Main
if [ "$1" = "logspout" ]; then
  logspoutUp
elif [ "$1" = "up" ]; then
  networkUp
elif [ "$1" = "down" ]; then
  networkDown
  echo "Do you also wish to destroy logspout?"
  select prompt in "Yes" "No"; do
    case $prompt in
      Yes ) logspoutDown "$MONITORING_LOGSPOUT_CONTAINER_NAME"; break;;
      No ) break;;
    esac
  done
elif [ "$1" = "reset" ]; then
  networkDown
  networkUp
elif [ "$1" = "start" ]; then
  startNetwork
elif [ "$1" = "stop" ]; then
  stopNetwork
else
  echo "No command specified"
  echo "Commands are: logspout, up, down, reset, start, stop"
fi
