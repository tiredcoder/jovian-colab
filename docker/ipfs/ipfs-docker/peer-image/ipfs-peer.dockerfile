# IPFS Peer Container Image With Private Network Bootstrapping, hostname announce support, mDNS toggle, and RelayClient support

# Default image
ARG IPFS_VERSION="v0.12.2"
FROM "ipfs/go-ipfs:${IPFS_VERSION}"

# Overwrite IPFS's start script
COPY start_ipfs.sh /usr/local/bin/start_ipfs
RUN chmod 0755 /usr/local/bin/start_ipfs
