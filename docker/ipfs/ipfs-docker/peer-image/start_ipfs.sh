#!/bin/sh
# ! MODIFIED BY RIK JANSSEN: !
#   - Added private network support
#   - Added mDNS toggle support
#   - Added AutoRelay toggle support
# Upstream: https://github.com/ipfs/go-ipfs/blob/v0.11.0/bin/container_daemon
set -e
user=ipfs
repo="$IPFS_PATH"

if [ `id -u` -eq 0 ]; then
  echo "Changing user to $user"
  # ensure folder is writable
  su-exec "$user" test -w "$repo" || chown -R -- "$user" "$repo"
  # restart script with new privileges
  exec su-exec "$user" "$0" "$@"
fi

# 2nd invocation with regular user
ipfs version

if [ -e "$repo/config" ]; then
  echo "Found IPFS fs-repo at $repo"
else
  case "$IPFS_PROFILE" in
    "") INIT_ARGS="" ;;
    *) INIT_ARGS="--profile=$IPFS_PROFILE" ;;
  esac
  ipfs init $INIT_ARGS
  ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
  ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080

  # Set up the swarm key, if provided

  SWARM_KEY_FILE="$repo/swarm.key"
  SWARM_KEY_PERM=0400

  # Create a swarm key from a given environment variable
  if [ ! -z "$IPFS_SWARM_KEY" ] ; then
    echo "Copying swarm key from variable..."
    echo -e "$IPFS_SWARM_KEY" >"$SWARM_KEY_FILE" || exit 1
    chmod $SWARM_KEY_PERM "$SWARM_KEY_FILE"
  fi

  # Unset the swarm key variable
  unset IPFS_SWARM_KEY

  # Check during initialization if a swarm key was provided and
  # copy it to the ipfs directory with the right permissions
  # WARNING: This will replace the swarm key if it exists
  if [ ! -z "$IPFS_SWARM_KEY_FILE" ] ; then
    echo "Copying swarm key from file..."
    install -m $SWARM_KEY_PERM "$IPFS_SWARM_KEY_FILE" "$SWARM_KEY_FILE" || exit 1
  fi

  # Unset the swarm key file variable
  unset IPFS_SWARM_KEY_FILE

fi

# Toggle multicast DNS peer discovery (default is true)
# https://github.com/ipfs/ipfs-docs/blob/6a961afbe4c5978e6c5cbdb7d0b27502953b79d5/docs/how-to/configure-node.md#discovery
if [ ! -z "$IPFS_MDNS" ]; then
  if [ "$IPFS_MDNS" = "false" ] || [ "$IPFS_MDNS" = "0" ] || [ "$IPFS_MDNS" = "no" ; then
    echo "Disabling multicast DNS peer discovery..."
    ipfs config --bool Discovery.MDNS.Enabled 0
  fi
fi

# Toggle AutoRelay (default is false)
# https://github.com/ipfs/go-ipfs/blob/v0.11.0/docs/experimental-features.md#autorelay
# https://github.com/ipfs/go-ipfs/blob/v0.11.0/docs/config.md#swarmrelayclient
# https://github.com/ipfs/go-ipfs/blob/v0.11.0/docs/config.md#swarmrelayservice
if [ ! -z "$IPFS_AUTORELAY" ]; then
  if [ "$IPFS_AUTORELAY" = "true" || [ "$IPFS_AUTORELAY" = "1" ] || [ "$IPFS_AUTORELAY" = "yes" ]; then
    echo "Enabling AutoRelay client..."
    ipfs config --json Swarm.RelayClient.Enabled true
  fi
fi

# Bootstrap Private Network
# https://github.com/ipfs/ipfs-docs/blob/d0462921172e425572ad1c0a9189a409bbe3c363/docs/how-to/modify-bootstrap-list.md
# We have to add the bootstrap nodes' peer ID to *all* the nodes in the private network
# if 'init' is set: get peer ID and exit (this node will be used as a bootstrap node)
# if client via JupyterLab: get list of bootstrap nodes for private network via Fabric
if [ ! -z "$IPFS_PNET_BOOTSTRAP_PEERS" ]; then
  echo "Bootstrapping private network..."
  if [ "$IPFS_PNET_BOOTSTRAP_PEERS" = "init" ]; then
    echo -e "Getting peer ID of bootstrap node...\n!!! BOOTSTRAP NODE PEER ID !!!\n$(ipfs id)"
    exit 0
  else
    echo "Removing default bootstrap nodes..."
    ipfs bootstrap rm --all

    echo "Adding bootstrap peers..."
    for PEER in $(echo "$IPFS_PNET_BOOTSTRAP_PEERS" | tr ';' '\n'); do
      ipfs bootstrap add "$PEER"
    done
  fi
fi

exec ipfs "$@"
