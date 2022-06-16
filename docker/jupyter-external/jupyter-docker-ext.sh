#!/usr/bin/env bash
#
# Creates external client (JupyterLab + IPFS node).
#
set -e
JUPYTER_NETWORK_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$JUPYTER_NETWORK_ROOT/jupyter-docker/.env"
JUPYTERLAB_UID=$(id -u)
JUPYTERLAB_GID=$(id -g)

prerequisitesInstall() {
  echo "Building client modules..."
  (
    cd "${JUPYTER_NETWORK_ROOT}/../../src/jupyter/fabric-gw-client" \
    && ./build.sh \
    && cp ./dist/*.tgz "${JUPYTER_NETWORK_ROOT}/../jupyter/jupyter-docker/jupyterlab-image/"
  )

  (
    cd "${JUPYTER_NETWORK_ROOT}/../../src/jupyter/ipfs-client" \
    && ./build.sh \
    && cp ./dist/*.whl "${JUPYTER_NETWORK_ROOT}/../jupyter/jupyter-docker/jupyterlab-image/"
  )

  echo "Building JupyterLab container image..."
  (
    cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker \
    && env JUPYTERLAB_UID=$JUPYTERLAB_UID JUPYTERLAB_GID=$JUPYTERLAB_GID docker-compose build --no-cache notebook.jupyter.localhost \
    && rm "${JUPYTER_NETWORK_ROOT}/../jupyter/jupyter-docker/jupyterlab-image/"*.{tgz,whl}
  )
}

networkUp() {
  echo "Starting *** EXTERNAL *** Jupyter network..."
  prerequisitesInstall
  (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env JUPYTERLAB_UID=$JUPYTERLAB_UID JUPYTERLAB_GID=$JUPYTERLAB_GID docker-compose up -d)
}

startNetwork() {
  echo "Resuming Jupyter network..."
  (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env JUPYTERLAB_UID=$JUPYTERLAB_UID JUPYTERLAB_GID=$JUPYTERLAB_GID docker-compose up -d)
}

stopNetwork() {
  echo "Stopping Jupyter network(s)..."
  (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && docker-compose stop)
}

networkDown() {
  echo "Destroying Jupyter network and removing the IPFS repository..."
  (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env JUPYTERLAB_UID=$JUPYTERLAB_UID JUPYTERLAB_GID=$JUPYTERLAB_GID docker-compose down -v)
  rm -rf "$JUPYTER_NETWORK_ROOT"/jupyter-data/ipfs/*
  echo "Removing JupyterLab image..."
  docker rmi "jc_demo_jupyterlab"
  echo "Done! Network was purged"
}

# Main
if [ "$1" = "up" ]; then
  networkUp
elif [ "$1" = "down" ]; then
  networkDown
elif [ "$1" = "reset" ]; then
  networkDown
  networkUp
elif [ "$1" = "start" ]; then
  startNetwork
elif [ "$1" = "stop" ]; then
  stopNetwork
else
  echo "No command specified"
  echo "Commands are: up, down, reset, start, stop"
fi
