#!/usr/bin/env bash
set -eu
CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
ACTION="${1:-?}"
CHAINCODE_DIR="$(readlink -f ${2:-$SCRIPT_DIR/../../src/fabric/chaincode/cc-ipfs})"

# Get the config
source "$SCRIPT_DIR/.env"

# Get the build function
source "$SCRIPT_DIR/../fabric/fabric-docker/scripts/base-functions.sh"
source "$SCRIPT_DIR/../fabric/fabric-docker/scripts/chaincode-functions.sh"

networkUp() {
  printHeadline "Starting Fabric devmode network" "U1F680"
  CHAINCODE_DIR="${CHAINCODE_DIR}" docker-compose up -d
  sleep 5

  printItalics "Generating crypto material" "U1F512"
  # NOTE: TLS is disabled in devmode and we are only preserving the peer's crypto material for optional testing purposes.
  rm -rf "$SCRIPT_DIR/fabric-config/msp/{admincerts,cacerts,keystore,signcerts,tlscacerts}"
  docker exec tools.fabric-ccdev.localhost cryptogen generate --config=./crypto-config.yaml >/dev/null
  mv -f "$SCRIPT_DIR/fabric-config/crypto-config/peerOrganizations/fabric-ccdev.localhost/peers/peer0.fabric-ccdev.localhost/msp/"* "$SCRIPT_DIR/fabric-config/msp/"
  cp "$SCRIPT_DIR/fabric-config/msp/signcerts/"peer*.pem "$SCRIPT_DIR/fabric-config/msp/admincerts/"
  rm -f "$SCRIPT_DIR/fabric-config/msp/admincerts/"Admin*.pem
  rm -rf "$SCRIPT_DIR/fabric-config/crypto-config"

  printItalics "Generating the genesis block" "U1F913"
  docker exec -i tools.fabric-ccdev.localhost configtxgen -profile SampleDevModeSolo -channelID syschannel -outputBlock genesisblock -configPath /var/hyperledger/config -outputBlock /var/hyperledger/config/genesisblock

  # Restart peer and orderer to get crypto and genesis block configs
  echo 'Restarting peer and orderer to get crypto and genesis block configs...'
  docker restart peer0.fabric-ccdev.localhost orderer0.fabric-ccdev.localhost >/dev/null
  sleep 3

  printItalics "Creating channel 'ch1'" "U1F913"
  docker exec -i tools.fabric-ccdev.localhost configtxgen -channelID ch1 -outputCreateChannelTx ch1.tx -profile SampleSingleMSPChannel -configPath /var/hyperledger/config
  docker exec -i peer0.fabric-ccdev.localhost peer channel create -o orderer0.fabric-ccdev.localhost:7050 -c ch1 -f ch1.tx

  printItalics "Joining peer to channel" "U1F913"
  docker exec -i peer0.fabric-ccdev.localhost peer channel join -b ch1.block
}

chaincodeStop() {
  printItalics "Stopping chaincode" "U1F60E"
  inputLog "CHAINCODE_DIR: $CHAINCODE_DIR"
  docker container inspect cc-nodejs.fabric-ccdev.localhost >/dev/null 2>&1 && docker kill cc-nodejs.fabric-ccdev.localhost >/dev/null 2>&1 || true
  echo "Chaincode container has stopped."
}

chaincodeStart() {
  printItalics "Running chaincode" "U1F60E"
  inputLog "CHAINCODE_DIR: $CHAINCODE_DIR"
  docker run --rm -d --name "cc-nodejs.fabric-ccdev.localhost" --volume="${CHAINCODE_DIR}:/mnt/chaincode" --workdir="/mnt/chaincode" --network="${DEMO_NETWORK_NAME}" "${COMPOSE_PROJECT_NAME}-nodejs:${CHAINCODE_NODE_VERSION}-alpine" sh -c "npm start -- --peer.address peer0.fabric-ccdev.localhost:7052 --chaincode-id-name 'ccdevmode:0.1'"  >/dev/null 2>&1
  echo "Chaincode is running in container 'cc-nodejs.fabric-ccdev.localhost'."
}

chaincodeApprove() {
  printHeadline "Approving and committing chaincode 'ccdevmode:0.1' on channel 'ch1'" "U1F60E"
  docker exec -i peer0.fabric-ccdev.localhost peer lifecycle chaincode approveformyorg -o orderer0.fabric-ccdev.localhost:7050 --channelID ch1 --name ccdevmode --version 0.1 --sequence 1 --signature-policy "OR ('SampleOrg.member')" --package-id ccdevmode:0.1
  docker exec -i peer0.fabric-ccdev.localhost peer lifecycle chaincode checkcommitreadiness orderer0.fabric-ccdev.localhost:7050 --channelID ch1 --name ccdevmode --version 0.1 --sequence 1 --signature-policy "OR ('SampleOrg.member')"
  docker exec -i peer0.fabric-ccdev.localhost peer lifecycle chaincode commit -o orderer0.fabric-ccdev.localhost:7050 --channelID ch1 --name ccdevmode --version 0.1 --sequence 1 --signature-policy "OR ('SampleOrg.member')" --peerAddresses peer0.fabric-ccdev.localhost:7051
}

chaincodeInvoke() {
  printItalics "Invoking chaincode" "U1F537"
  inputLog "CHAINCODE_DIR: $CHAINCODE_DIR"
  inputLog "CC_INVOKE_ARGS: $CC_INVOKE_ARGS"
  docker exec -i peer0.fabric-ccdev.localhost peer chaincode invoke -o orderer0.fabric-ccdev.localhost:7050 -C ch1 -n ccdevmode -c "${CC_INVOKE_ARGS}"
}

networkDown() {
  printHeadline "Destroying the Fabric devmode network" "U1F68F"
  CHAINCODE_DIR="${CHAINCODE_DIR}" docker-compose down
  rm -f "$SCRIPT_DIR/fabric-config/"{genesisblock,ch1.tx,ch1.block}
  rm -rf "$SCRIPT_DIR/fabric-config/msp/"{admincerts,cacerts,keystore,signcerts,tlscacerts}
}

# Main
cd "$SCRIPT_DIR"
case "$ACTION" in
  "up")
    networkUp
    ;;
  "down")
    chaincodeStop
    networkDown
    ;;
  "build")
    printItalics "Building chaincode 'ccdevmode' on channel 'ch1'" "U1F618"
    chaincodeBuild "ccdevmode" "node" "$CHAINCODE_DIR" "$CHAINCODE_NODE_VERSION" 
    ;;
  "start")
    chaincodeStop
    chaincodeStart
    ;;
  "stop")
    chaincodeStop
    ;;
  "commit")
    chaincodeApprove
    ;;
  "rebuild")
    chaincodeStop
    printItalics "Rebuilding chaincode 'ccdevmode' on channel 'ch1'" "U1F618"
    chaincodeBuild "ccdevmode" "node" "$CHAINCODE_DIR" "$CHAINCODE_NODE_VERSION" 
    chaincodeStart
    ;;
  "invoke")
    CC_INVOKE_DEFAULT_ARGS='{"Args":["createNetwork","net1","boot","key","pin","acl"]}'
    CC_INVOKE_ARGS="${2:-$CC_INVOKE_DEFAULT_ARGS}"
    CHAINCODE_DIR="$(readlink -f ${3:-$SCRIPT_DIR/../../src/fabric/chaincode/cc-ipfs})"
    chaincodeInvoke
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo "Basic commands are: up, down, build, start, commit, rebuild, invoke"
    cd "$CURRENT_DIR"
    exit 1
    ;;
esac
cd "$CURRENT_DIR"
