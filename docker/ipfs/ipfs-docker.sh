#!/usr/bin/env bash
set -e
IPFS_NETWORK_ROOT="$(cd "$(dirname "$0")" && pwd)"
IPFS_UID=$(id -u)
IPFS_GID=$(id -g)

bootstrap() {
  echo "Bootstrapping IPFS..."
  (cd "$IPFS_NETWORK_ROOT"/ipfs-docker && env IPFS_UID=$IPFS_UID IPFS_GID=$IPFS_GID docker-compose -f compose.ipfs-bootstrap.yml up -d)  
  sleep 10
  (cd "$IPFS_NETWORK_ROOT"/ipfs-docker && env IPFS_UID=$IPFS_UID IPFS_GID=$IPFS_GID docker-compose -f compose.ipfs-bootstrap.yml logs | grep '"ID"')
  sleep 5
  (cd "$IPFS_NETWORK_ROOT"/ipfs-docker && env IPFS_UID=$IPFS_UID IPFS_GID=$IPFS_GID docker-compose -f compose.ipfs-bootstrap.yml down)
}

generateClusterTLS() {
  echo "Generating TLS crypto material for IPFS clusters (Pinning Service API)..."
  
  echo "Creating 'crypto-config' directory hierarchy..."
  mkdir -p "$IPFS_NETWORK_ROOT/crypto-config/"{orga,orgb,orgc}/pnet0/{cluster0,cluster1}
  mkdir -p "$IPFS_NETWORK_ROOT/crypto-config/orgb/pnet1"/{cluster0,cluster1}

  echo "Generating TLS certs and keys using openssl..."
 
  opensslcmd() {
    local HOST="$1"
    openssl req                                \
    -x509                                      \
    -newkey rsa:4096                           \
    -sha256                                    \
    -days 365                                  \
    -nodes                                     \
    -keyout pinsvcapi.key                      \
    -out pinsvcapi.crt                         \
    -subj "/C=NL/L=Amsterdam/O=OS3/CN=${HOST}" \
    -addext "subjectAltName=DNS:${HOST}"       \
    >/dev/null 2>&1  
  }
  
  local ORGs=("orga" "orgb" "orgc")
  for ORG in "${ORGs[@]}"; do
    for i in {0..1}; do
      local HOST="cluster${i}.pnet0.${ORG}.ipfs.localhost"
      (
        cd "$IPFS_NETWORK_ROOT/crypto-config/$ORG/pnet0/cluster$i"
        opensslcmd "$HOST"
      )
    done
  done
  for i in {0..1}; do
    local HOST="cluster${i}.pnet1.orgb.ipfs.localhost"
    (
      cd "$IPFS_NETWORK_ROOT/crypto-config/orgb/pnet1/cluster$i"
      opensslcmd "$HOST"
    )
  done
}

networkUp() {
  generateClusterTLS
  startNetwork
}

startNetwork() {
  echo "Starting IPFS network..."
  (cd "$IPFS_NETWORK_ROOT"/ipfs-docker && env IPFS_UID=$IPFS_UID IPFS_GID=$IPFS_GID docker-compose up -d)
  sleep 6
}

stopNetwork() {
  echo "Stopping IPFS network..."
  (cd "$IPFS_NETWORK_ROOT"/ipfs-docker && env IPFS_UID=$IPFS_UID IPFS_GID=$IPFS_GID docker-compose stop)
  sleep 4
}

networkDown() {
  echo "Destroying IPFS network..."
  (cd "$IPFS_NETWORK_ROOT"/ipfs-docker && env IPFS_UID=$IPFS_UID IPFS_GID=$IPFS_GID docker-compose down -v)
  echo "Removing generated TLS crypto material..."
  rm -rf "$IPFS_NETWORK_ROOT/crypto-config"
  echo "Done! Network was purged"
}

# Main
if [ "$1" = "bootstrap" ]; then
  bootstrap
elif [ "$1" = "up" ]; then
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
  echo "Commands are: bootstrap, up, down, reset, start, stop"
fi
