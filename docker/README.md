# Demo Infrastructure
Creates a virtual infrastructure, using *[Docker Compose](https://docs.docker.com/compose)*, that consists of *[JupyterLab](https://jupyter.org)*, *[IPFS](https://ipfs.io)* and *[Hyperledger Fabric](https://www.hyperledger.org/use/fabric)*. \
Note that Fabric and IPFS are only accessible from within the demo's network created by Docker Compose (i.e. we can't access the demo from the outside).
[Fablo](https://github.com/hyperledger-labs/fablo) (version 1.0.0) was used to generate the *initial* Hyperledger Fabric infrastructure configuration (we *heavily* modified this). \
Please see the '.env' file(s) for the configuration (e.g. which software version(s) to use, secret(s), etc.). Do *not* run multiple instances of this demo at the same time.

**SECURITY WARNING:** Do not expose this infrastructure directly to the Internet!

## Overview
![Infrastructure overview](infra.svg)

## Requirements
The infrastructure consists of about 50 Docker containers.
 - Hardware: Tested on an x86_64 QEMU/KVM VM with a: 65GiB virtual disk (SSD backend), 10GiB RAM, 6 core CPU (Intel Xeon E3 1240L v5 backend).
 - Software: See tables below.

## Versions
The infrastructure consists of the software mentioned in the table below. We use Docker images for most of this software.

| Software                                           | Version                                                                   |
| -------------------------------------------------- | ------------------------------------------------------------------------- |
| Ubuntu Server                                      | [20.04.4 LTS](https://releases.ubuntu.com/20.04/)                           |
| Docker                                             | [20.10.14](https://docs.docker.com/engine)                                |
| Docker Compose                                     | [1.29.2](https://docs.docker.com/compose)                                 |
| IPFS Peer                                          | [0.11.0](https://github.com/ipfs/go-ipfs/tree/v0.11.0)                    |
| IPFS Cluster                                       | [0.14.2](https://github.com/ipfs/ipfs-cluster/tree/v0.14.2)               |
| Hyperledger Fabric                                 | [2.4.1](https://hyperledger-fabric.readthedocs.io/en/release-2.4/)        |
| Fabric Client Node.js SDK (Legacy Application API) | [2.2.11](https://github.com/hyperledger/fabric-sdk-node/tree/v2.2.11)     |
| Fabric Chaincode Node.js SDK (Contract API)        | [2.4.1](https://github.com/hyperledger/fabric-chaincode-node/tree/v2.4.1) |
| Fabric Gateway Node.js SDK (Application API)       | [1.0.1](https://github.com/hyperledger/fabric-gateway/tree/v1.0.1)        |
| JupyterLab Notebook                                | [3.2.9](https://jupyterlab.readthedocs.io/en/3.2.x/)                      |
| Firefox                                            | [99](https://www.mozilla.org/en-US/firefox/99.0/releasenotes/)            |

### Node.js
The Hyperledger Fabric Node.js SDKs require different versions:

| Fabric SDK                      | Node.js Version                                                                         |
| ------------------------------- | --------------------------------------------------------------------------------------- |
| Client (Legacy Application API) | [12](https://github.com/hyperledger/fabric-sdk-node/tree/v2.2.11#build-and-test)        |
| Chaincode (Contract API)        | [16](https://github.com/hyperledger/fabric-chaincode-node/blob/v2.4.1/COMPATIBILITY.md) |
| Gateway (Application API)       | [14](https://github.com/hyperledger/fabric-gateway/tree/v1.0.1#install-pre-reqs)        |

As per the [documentation](https://github.com/hyperledger/fabric/blob/8a4c7f3bdb17c18fe6c56ff7e3e2fc008e223005/docs/source/sdk_chaincode.md#fabric-contract-apis-and-application-apis), we use the client SDK (legacy) for CA administrative actions and the Gateway SDK as the actual client (i.e. JupyterLab).

## Internal Endpoints Overview
The following network sockets are used *within* the created virtual infrastructure. These endpoints are *not* reachable from the Docker host / outside.

| Component(s)                     | Endpoint |
| -------------------------------- | -------- |
| IPFS libp2p swarm                | TCP 4001 |
| IPFS Peer API (daemon/rw access) | TCP 5001 |
| IPFS Cluster HTTP API            | TCP 9094 |
| IPFS Cluster swarm               | TCP 9096 |
| IPFS Cluster Prometheus Metrics  | TCP 8888 |
| Fabric CA HTTP API               | TCP 7054 |
| Fabric Orderer                   | TCP 7050 |
| Fabric Peer: listen and gossip   | TCP 7051 |
| Fabric Peer: chaincode listen    | TCP 7052 |
| Fabric Prometheus Metrics        | TCP 9443 |
| Node exporter Prometheus Metrics | TCP 9100 |
| cAdvisor Web UI and metrics      | TCP 8080 |
| Prometheus Web UI and metrics    | TCP 9090 |
| Grafana Web UI                   | TCP 3000 |
| Hyperledger Explorer Web UI      | TCP 8080 |
| JupyterLab Notebook Web UI       | TCP 8888 |

## Docker Host Network Bindings
The following network sockets are used on the Docker host machine (configured via the .env files). We use these network bindings to selectively expose the container endpoints (see above) to the Docker host machine.
 - IPFS peer APIs (IPFS Web UI access): 127.0.0.1:5000 - 127.0.0.1:5003
 - IPFS cluster HTTP APIs: 127.0.0.1:6000 - 127.0.0.1:6003
 - Monitoring tools Web UIs: 127.0.0.1:7000 - 127.0.0.1:7004
 - JupyterLab Notebook Web UI: 127.0.0.1:8888

## Possibly change JupyterLab's UID and GID
Several directories will be mounted into the JupyterLab container at */home/jovyan/work*. You can specify your user ID and group ID via the .env file. This allows for data sharing between the container and the Docker host.

## Optional: change the secrets in the .env file
**Generate IPFS cluster secret(s):**
```
echo "$(od -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')"
```
**Generate IPFS swarm secret(s):**
```
go get github.com/Kubuxu/go-ipfs-swarm-key-gen/ipfs-swarm-key-gen
echo "$(ipfs-swarm-key-gen)"
```
Replace the newlines with '\n' (see the .env file for examples).

**NOTICE:** Please follow the steps below in the correct order (we use multiple Docker Compose files which create containers in the same network).

## Boostrap IPFS
We need to provide bootstrap nodes for each private IPFS network.
 1. Launch the IPFS bootstrap nodes and note their peer ID:
    cd ./ipfs 
    docker-compose -f compose.ipfs-bootstrap.yml up
 2. Add the bootstrap peer IDs in multiaddr format to the .env file (e.g. the multiaddr of organization A's peer0 for pnet0 is "/dns4/peer0.pnet0.orga.ipfs.localhost/tcp/4001/p2p/\<PEERID\>"). See the .env file for examples.
 3. Destroy the bootstrap containers (the data/configurations will be preserved):
    docker-compose -f compose.ipfs-bootstrap.yml down

## Start IPFS
(Make sure you bootstrapped IPFS first.)
```
docker-compose up -d
```

## Start Fabric
```
cd ../fabric
./fabric-docker.sh up
```

## Start JupyterLab (and an IPFS node client)
```
cd ../jupyter
docker-compose up -d
```

## Access JupyterLab from your web browser
[http://127.0.0.1:8888](http://127.0.0.1:8888)

## Optional: access JupyterLab via remote using an SSH tunnel (i.e. if you are not running Docker on your local system)
```
ssh <user>@<dockerhost> -L 127.0.0.1:8888:127.0.0.1:8888
```

## Verify that Docker is running
```
docker --help
docker info
docker images | less -S
docker ps | less -S
docker network ls
docker network inspect jovian-colab_demo-net
```

## Verify that IPFS is running
**IPFS node/peer CLI examples:**
```
docker exec peer0.pnet0.orga.ipfs.localhost ipfs --help
docker exec peer0.pnet0.orga.ipfs.localhost ipfs id
docker exec peer0.pnet0.orga.ipfs.localhost ipfs bootstrap list
docker exec peer0.pnet0.orga.ipfs.localhost ipfs swarm peers
```
**IPFS cluster CLI examples:**
```
docker exec cluster0.pnet0.orga.ipfs.localhost ipfs-cluster-ctl --help
docker exec cluster0.pnet0.orga.ipfs.localhost ipfs-cluster-ctl peers ls
```

## Verify that Fabric is running
**CLI examples:**
```
docker exec cli.orgb.fabric.localhost peer --help
docker exec cli.orgb.fabric.localhost peer channel list
./fabric-docker.sh channel getinfo orgb-chain orgb peer0
```

## Monitoring
See the README.md file in the 'monitoring' directory.

## Troubleshooting
You can create a Ubuntu-based container to troubleshoot the infrastructure (i.e. to install tools and access all the endpoints from *within* the same virtual network).
```
docker run -it --rm --name troubleshoot --network jovian-colab_demo-net ubuntu:focal bash
cd ~
apt update && apt upgrade -y && apt install -y curl less
```

## Stop/Cleanup the demo
(From within the docker directory.)
```
cd ./jupyter
docker-compose down
cd ../fabric
./fabric-docker.sh down
cd ../ipfs
docker-compose down
```

## Possibly remove the created Docker volumes
The demo can use up to several GBs of Docker volumes, delete them if needed. **WARNING**: The below command will delete *all* your Docker volumes!
```
docker volume prune
```
