#!/usr/bin/env bash
#
# Creates specified amount of client (JupyterLab + IPFS node) instances.
# Each instance is a Docker compose project and is accessibile behind a ngnix reverse proxy.
# E.g. './jupyter-docker.sh up 2' creates 2 instances accessibile via 'http://<NGINX_HTTP_SOCKET>/notebook.jupyter-<instance number>.localhost'.
#
set -e
JUPYTER_NETWORK_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$JUPYTER_NETWORK_ROOT/jupyter-docker/.env"

proxyStart() {
  local INSTANCES="$1"
  echo "Starting reverse proxy on $NGINX_HTTP_SOCKET..."

  echo -e "# !!! AUTO-GENERATED FILE BY jupyter-docker.sh !!!\nserver {\n  listen 0.0.0.0:8080;" > "${JUPYTER_NETWORK_ROOT}/jupyter-docker/nginx-proxy.conf"
  for ((i=1;i<=INSTANCES;i++)); do
    echo -e "  location /notebook.jupyter-$i.localhost {\n    include /etc/nginx/snippets/proxy.conf;\n    proxy_pass http://notebook.jupyter-$i.localhost:8888;\n  }" >> "${JUPYTER_NETWORK_ROOT}/jupyter-docker/nginx-proxy.conf"
  done
  echo '}' >> "${JUPYTER_NETWORK_ROOT}/jupyter-docker/nginx-proxy.conf"

  docker run -d --name "nginx.jupyter.localhost" --network="${DEMO_NETWORK_NAME}" -p "${NGINX_HTTP_SOCKET}:8080" -v "${JUPYTER_NETWORK_ROOT}/jupyter-docker/nginx-proxy.conf:/etc/nginx/conf.d/default.conf:ro" -v "${JUPYTER_NETWORK_ROOT}/jupyter-docker/nginx-snippet-proxy.conf:/etc/nginx/snippets/proxy.conf:ro" -e LOGSPOUT=ignore "${NGINX_IMAGE}" >/dev/null 2>&1
}

prerequisitesInstall() {
  echo "Building client modules..."
  (
    cd "${JUPYTER_NETWORK_ROOT}/../../src/jupyter/fabric-gw-client" \
    && ./build.sh \
    && cp ./dist/*.tgz "${JUPYTER_NETWORK_ROOT}/jupyter-docker/jupyterlab-image/"
  )

  (
    cd "${JUPYTER_NETWORK_ROOT}/../../src/jupyter/ipfs-client" \
    && ./build.sh \
    && cp ./dist/*.whl "${JUPYTER_NETWORK_ROOT}/jupyter-docker/jupyterlab-image/"
  )

  echo "Building JupyterLab container image..."
  (
    cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker \
    && env INSTANCE='build' docker-compose build --no-cache notebook.jupyter.localhost \
    && rm "${JUPYTER_NETWORK_ROOT}/jupyter-docker/jupyterlab-image/"*.{tgz,whl}
  )
}

networkUp() {
  local INSTANCES="$1"
  echo "Starting $INSTANCES Jupyter network(s)..."

  prerequisitesInstall

  for ((i=1;i<=INSTANCES;i++)); do
    echo "Creating directory hierarchy for the IPFS repositories..."
    mkdir "$JUPYTER_NETWORK_ROOT"/jupyter-data/ipfs/"${COMPOSE_PROJECT_NAME}-$i"
    
    # Env vars given at docker-compose invoke supersede .env file (allowing us to set the project name for each instance)
    (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}-$i" INSTANCE="$i" docker-compose up -d)

    echo "Copying notebooks to local container storage for instance $i..."
    docker exec -i "notebook.jupyter-$i.localhost" sh -c "mkdir /home/jovyan/work/local && cp -r /home/jovyan/work/notebook/* /home/jovyan/work/local/"
  done
  
  proxyStart "$INSTANCES"
}

startNetwork() {
  echo "Resuming Jupyter network(s)..."
  local i=1
  while [ $(cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && docker-compose -p "${COMPOSE_PROJECT_NAME}-$i" ps -q | wc -c) -ne 0 ]; do
    (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}-$i" INSTANCE="$i" docker-compose up -d)
    (( i++ ))
  done
  docker start nginx.jupyter.localhost >/dev/null 2>&1
}

stopNetwork() {
  echo "Stopping Jupyter network(s)..."
  local i=1
  while [ $(cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && docker-compose -p "${COMPOSE_PROJECT_NAME}-$i" ps -q | wc -c) -ne 0 ]; do
    (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}-$i" INSTANCE="$i" docker-compose stop)
    (( i++ ))
  done
  docker stop nginx.jupyter.localhost >/dev/null 2>&1
}

networkDown() {
  echo "Destroying Jupyter network(s) and removing the IPFS repositories..."
  local i=1
  while [ $(cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && docker-compose -p "${COMPOSE_PROJECT_NAME}-$i" ps -q | wc -c) -ne 0 ]; do
    (cd "$JUPYTER_NETWORK_ROOT"/jupyter-docker && env COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}-$i" INSTANCE="$i" docker-compose down)
    rm -rf "$JUPYTER_NETWORK_ROOT"/jupyter-data/ipfs/"${COMPOSE_PROJECT_NAME}-$i"
    ((i++))
  done
  echo "Removing reverse proxy..."
  docker stop nginx.jupyter.localhost >/dev/null 2>&1 && docker rm nginx.jupyter.localhost >/dev/null 2>&1
  rm "${JUPYTER_NETWORK_ROOT}/jupyter-docker/nginx-proxy.conf"
  echo "Removing JupyterLab image..."
  docker rmi "jc_demo_jupyterlab"
  echo "Done! Network was purged"
}

# Main
if [ "$1" = "up" ]; then
  networkUp "${2:-2}" # Default is 2 instances
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
