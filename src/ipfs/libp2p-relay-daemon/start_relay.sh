#!/bin/sh
# libp2p-relay-daemon start script
# Based on:
#  - https://github.com/ipfs/go-ipfs/blob/v0.12.2/bin/container_daemon
#  - https://github.com/libp2p/go-libp2p-relay-daemon/blob/bb55da132ad49ce8d2cee881ca05f40b04a2bb7d/etc/libp2p-relay-daemon.sh
set -e


# File descriptor limit for TCP connections
ulimit -n 65536


# Private network swarm key
SWARM_KEY_FILE="/usr/local/etc/libp2p-relay-daemon/swarm.key"

# Create a swarm key from a given environment variable
if [ ! -z "$IPFS_SWARM_KEY" ] ; then
  echo "Copying swarm key from env variable..."
  if [ -f "$SWARM_KEY_FILE" ] ; then
    chmod 0600 "$SWARM_KEY_FILE"
  fi
  echo -e "$IPFS_SWARM_KEY" >"$SWARM_KEY_FILE" || exit 1
  chmod 0400 "$SWARM_KEY_FILE"
fi
unset IPFS_SWARM_KEY

# Check during initialization if a swarm key was provided and
# copy it to the local etc directory with the right permissions
# WARNING: This will replace the swarm key if it exists
if [ ! -z "$IPFS_SWARM_KEY_FILE" ] ; then
  echo "Copying swarm key from file..."
  install -m 0400 "$IPFS_SWARM_KEY_FILE" "$SWARM_KEY_FILE" || exit 1
fi
unset IPFS_SWARM_KEY_FILE


# Bootstrap peers
if [ ! -z "$IPFS_BOOTSTRAP_PEERS" ]; then
  CONFIG_FILE='/usr/local/etc/libp2p-relay-daemon/config.json'
  echo "Adding bootstrap peers from env variable to ${CONFIG_FILE}..."
  OUT=''
  for PEER in $(echo "$IPFS_BOOTSTRAP_PEERS" | tr ';' '\n'); do
    OUT="${OUT}\"${PEER}\","
  done
  jq ".Network.BootstrapPeers = [${OUT%?}]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
  mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi
unset IPFS_BOOTSTRAP_PEERS


# Start relay with the swarm key, if provided
if [ -f "$SWARM_KEY_FILE" ] ; then
  exec libp2p-relay-daemon --swarmkey="$SWARM_KEY_FILE" "$@"
else
  exec libp2p-relay-daemon "$@"
fi
