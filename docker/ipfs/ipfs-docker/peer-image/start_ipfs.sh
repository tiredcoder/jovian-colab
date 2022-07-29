#!/bin/sh
# ! MODIFIED BY RIK JANSSEN: !
#   - Added private network support
#   - Added hostname announce support
#   - Added mDNS toggle support
#   - Added RelayClient support
# Upstream: https://github.com/ipfs/go-ipfs/blob/v0.12.2/bin/container_daemon
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


# Announce FQDN instead of IPs
if [ ! -z "$IPFS_ANNOUNCE_HOST" ]; then
  if [ "$IPFS_ANNOUNCE_HOST" = "true" ] || [ "$IPFS_ANNOUNCE_HOST" = "1" ] || [ "$IPFS_ANNOUNCE_HOST" = "yes" ]; then
    echo "Only announcing FQDN (DNS4) on TCP 4001..."
    ipfs config --json Addresses.Announce "[\"/dns4/$(hostname -f)/tcp/4001\"]"
  else
    echo "Announcing given hostname '$IPFS_ANNOUNCE_HOST' and FQDN (DNS4) on TCP 4001..."
    ipfs config --json Addresses.Announce "[\"/dns4/$(hostname -f)/tcp/4001\",\"/dns4/${IPFS_ANNOUNCE_HOST}/tcp/4001\"]"
  fi
fi
unset IPFS_ANNOUNCE_HOST


# Toggle multicast DNS peer discovery (default is true)
# https://github.com/ipfs/ipfs-docs/blob/6a961afbe4c5978e6c5cbdb7d0b27502953b79d5/docs/how-to/configure-node.md#discovery
if [ ! -z "$IPFS_MDNS" ]; then
  if [ "$IPFS_MDNS" = "false" ] || [ "$IPFS_MDNS" = "0" ] || [ "$IPFS_MDNS" = "no" ]; then
    echo "Disabling multicast DNS peer discovery..."
    ipfs config --bool Discovery.MDNS.Enabled 0
  fi
fi
unset IPFS_MDNS


# Enable the relay client using static relays (default is false)
# The node will announce itself via the relay *and* via its default announcements
# This allows direct neighbors to connect without using the relay (as is the normal case in private reachability mode)
# https://github.com/ipfs/go-ipfs/blob/v0.12.2/docs/config.md#swarmrelayclient
# https://github.com/ipfs/kubo/blob/v0.12.2/test/sharness/t0182-circuit-relay.sh
if [ ! -z "$IPFS_CLIENT_RELAYS" ]; then
  echo 'Forcing reachability as *public* (private only allows traffic via relay, even when we have a direct neighbor node)...'
  ipfs config Internal.Libp2pForceReachability public
  echo "Enabling relay client..."
  ipfs config --json Swarm.RelayClient.Enabled true
  echo "Adding static relay(s)..."
  RELAYS='['
  ANNOUNCE='['
  for RELAY in $(echo "$IPFS_CLIENT_RELAYS" | tr ';' '\n'); do
    RELAYS="${RELAYS}\"${RELAY}\","
    ANNOUNCE="${ANNOUNCE}\"${RELAY}/p2p-circuit\","
  done
  RELAYS="${RELAYS%?}]"
  ANNOUNCE="${ANNOUNCE%?}]"
  ipfs config --json Swarm.RelayClient.StaticRelays "$RELAYS"
  echo 'Also announcing peer via relay(s) (account for NAT / firewalled network(s))...'
  ipfs config --json Addresses.AppendAnnounce "$ANNOUNCE"
fi
unset IPFS_CLIENT_RELAYS


# Bootstrap Private Network
# https://github.com/ipfs/ipfs-docs/blob/d0462921172e425572ad1c0a9189a409bbe3c363/docs/how-to/modify-bootstrap-list.md
# We have to add the bootstrap nodes' peer ID to *all* the nodes in the private network
# if 'init' is set: get peer ID and exit (this node will be used as a bootstrap node)
# if client via JupyterLab: get list of bootstrap nodes for private network via Fabric
if [ ! -z "$IPFS_PNET_BOOTSTRAP_PEERS" ]; then
  echo "Bootstrapping private network..."
  if [ "$IPFS_PNET_BOOTSTRAP_PEERS" = "init" ]; then
    echo 'Forcing reachability as public (the bootstrap node can also serve as a v2 relay)...'
    ipfs config Internal.Libp2pForceReachability public
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
unset IPFS_PNET_BOOTSTRAP_PEERS


# Start IPFS node
exec ipfs "$@"
