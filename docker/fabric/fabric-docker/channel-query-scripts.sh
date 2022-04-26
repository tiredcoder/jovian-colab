#!/usr/bin/env bash

source "$FABLO_NETWORK_ROOT/fabric-docker/scripts/channel-query-functions.sh"

set -eu

channelQuery() {
  echo "-> Channel query: " + "$@"

  if [ "$#" -eq 1 ]; then
    printChannelsHelp

  elif [ "$1" = "list" ] && [ "$2" = "orga" ] && [ "$3" = "peer0" ]; then

    peerChannelListTls "cli.orga.fabric.localhost" "peer0.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif
    [ "$1" = "list" ] && [ "$2" = "orga" ] && [ "$3" = "peer1" ]
  then

    peerChannelListTls "cli.orga.fabric.localhost" "peer1.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif
    [ "$1" = "list" ] && [ "$2" = "orgb" ] && [ "$3" = "peer0" ]
  then

    peerChannelListTls "cli.orgb.fabric.localhost" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif
    [ "$1" = "list" ] && [ "$2" = "orgb" ] && [ "$3" = "peer1" ]
  then

    peerChannelListTls "cli.orgb.fabric.localhost" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif
    [ "$1" = "list" ] && [ "$2" = "orgc" ] && [ "$3" = "peer0" ]
  then

    peerChannelListTls "cli.orgc.fabric.localhost" "peer0.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif
    [ "$1" = "list" ] && [ "$2" = "orgc" ] && [ "$3" = "peer1" ]
  then

    peerChannelListTls "cli.orgc.fabric.localhost" "peer1.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif

    [ "$1" = "getinfo" ] && [ "$2" = "consortium-chain" ] && [ "$3" = "orga" ] && [ "$4" = "peer0" ]
  then

    peerChannelGetInfoTls "consortium-chain" "cli.orga.fabric.localhost" "peer0.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "peer0.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "peer0.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "peer0.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer0" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer0.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "consortium-chain" ] && [ "$3" = "orga" ] && [ "$4" = "peer1" ]
  then

    peerChannelGetInfoTls "consortium-chain" "cli.orga.fabric.localhost" "peer1.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "peer1.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "peer1.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "peer1.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orga" ] && [ "$5" = "peer1" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "consortium-chain" "cli.orga.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer1.orga.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "consortium-chain" ] && [ "$3" = "orgb" ] && [ "$4" = "peer0" ]
  then

    peerChannelGetInfoTls "consortium-chain" "cli.orgb.fabric.localhost" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orga.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "consortium-chain" ] && [ "$3" = "orgb" ] && [ "$4" = "peer1" ]
  then

    peerChannelGetInfoTls "consortium-chain" "cli.orgb.fabric.localhost" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "consortium-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "consortium-chain" ] && [ "$3" = "orgc" ] && [ "$4" = "peer0" ]
  then

    peerChannelGetInfoTls "consortium-chain" "cli.orgc.fabric.localhost" "peer0.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "peer0.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "peer0.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "peer0.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer0" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer0.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "consortium-chain" ] && [ "$3" = "orgc" ] && [ "$4" = "peer1" ]
  then

    peerChannelGetInfoTls "consortium-chain" "cli.orgc.fabric.localhost" "peer1.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "peer1.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "peer1.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "peer1.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "consortium-chain" ] && [ "$4" = "orgc" ] && [ "$5" = "peer1" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "consortium-chain" "cli.orgc.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer1.orgc.fabric.localhost:7051" "crypto-orderer/tlsca.orgc.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "orgb-chain" ] && [ "$3" = "orgb" ] && [ "$4" = "peer0" ]
  then

    peerChannelGetInfoTls "orgb-chain" "cli.orgb.fabric.localhost" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer0" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer0.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif
    [ "$1" = "getinfo" ] && [ "$2" = "orgb-chain" ] && [ "$3" = "orgb" ] && [ "$4" = "peer1" ]
  then

    peerChannelGetInfoTls "orgb-chain" "cli.orgb.fabric.localhost" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "config" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchConfigTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "lastBlock" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchLastBlockTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "firstBlock" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 7 ]; then
    FILE_NAME=$6

    peerChannelFetchFirstBlockTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  elif [ "$1" = "fetch" ] && [ "$2" = "block" ] && [ "$3" = "orgb-chain" ] && [ "$4" = "orgb" ] && [ "$5" = "peer1" ] && [ "$#" = 8 ]; then
    FILE_NAME=$6
    BLOCK_NUMBER=$7

    peerChannelFetchBlockTls "orgb-chain" "cli.orgb.fabric.localhost" "${FILE_NAME}" "${BLOCK_NUMBER}" "peer1.orgb.fabric.localhost:7051" "crypto-orderer/tlsca.orgb.fabric.localhost-cert.pem"

  else

    printChannelsHelp
  fi

}

printChannelsHelp() {
  echo "Channel management commands:"
  echo ""

  echo "fablo channel list orga peer0"
  echo -e "\t List channels on 'peer0' of 'orgA'".
  echo ""

  echo "fablo channel list orga peer1"
  echo -e "\t List channels on 'peer1' of 'orgA'".
  echo ""

  echo "fablo channel list orgb peer0"
  echo -e "\t List channels on 'peer0' of 'orgB'".
  echo ""

  echo "fablo channel list orgb peer1"
  echo -e "\t List channels on 'peer1' of 'orgB'".
  echo ""

  echo "fablo channel list orgc peer0"
  echo -e "\t List channels on 'peer0' of 'orgC'".
  echo ""

  echo "fablo channel list orgc peer1"
  echo -e "\t List channels on 'peer1' of 'orgC'".
  echo ""

  echo "fablo channel getinfo consortium-chain orga peer0"
  echo -e "\t Get channel info on 'peer0' of 'orgA'".
  echo ""
  echo "fablo channel fetch config consortium-chain orga peer0 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer0' of 'orgA'".
  echo ""
  echo "fablo channel fetch lastBlock consortium-chain orga peer0 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer0' of 'orgA'".
  echo ""
  echo "fablo channel fetch firstBlock consortium-chain orga peer0 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer0' of 'orgA'".
  echo ""

  echo "fablo channel getinfo consortium-chain orga peer1"
  echo -e "\t Get channel info on 'peer1' of 'orgA'".
  echo ""
  echo "fablo channel fetch config consortium-chain orga peer1 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer1' of 'orgA'".
  echo ""
  echo "fablo channel fetch lastBlock consortium-chain orga peer1 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer1' of 'orgA'".
  echo ""
  echo "fablo channel fetch firstBlock consortium-chain orga peer1 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer1' of 'orgA'".
  echo ""

  echo "fablo channel getinfo consortium-chain orgb peer0"
  echo -e "\t Get channel info on 'peer0' of 'orgB'".
  echo ""
  echo "fablo channel fetch config consortium-chain orgb peer0 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer0' of 'orgB'".
  echo ""
  echo "fablo channel fetch lastBlock consortium-chain orgb peer0 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer0' of 'orgB'".
  echo ""
  echo "fablo channel fetch firstBlock consortium-chain orgb peer0 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer0' of 'orgB'".
  echo ""

  echo "fablo channel getinfo consortium-chain orgb peer1"
  echo -e "\t Get channel info on 'peer1' of 'orgB'".
  echo ""
  echo "fablo channel fetch config consortium-chain orgb peer1 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer1' of 'orgB'".
  echo ""
  echo "fablo channel fetch lastBlock consortium-chain orgb peer1 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer1' of 'orgB'".
  echo ""
  echo "fablo channel fetch firstBlock consortium-chain orgb peer1 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer1' of 'orgB'".
  echo ""

  echo "fablo channel getinfo consortium-chain orgc peer0"
  echo -e "\t Get channel info on 'peer0' of 'orgC'".
  echo ""
  echo "fablo channel fetch config consortium-chain orgc peer0 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer0' of 'orgC'".
  echo ""
  echo "fablo channel fetch lastBlock consortium-chain orgc peer0 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer0' of 'orgC'".
  echo ""
  echo "fablo channel fetch firstBlock consortium-chain orgc peer0 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer0' of 'orgC'".
  echo ""

  echo "fablo channel getinfo consortium-chain orgc peer1"
  echo -e "\t Get channel info on 'peer1' of 'orgC'".
  echo ""
  echo "fablo channel fetch config consortium-chain orgc peer1 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer1' of 'orgC'".
  echo ""
  echo "fablo channel fetch lastBlock consortium-chain orgc peer1 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer1' of 'orgC'".
  echo ""
  echo "fablo channel fetch firstBlock consortium-chain orgc peer1 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer1' of 'orgC'".
  echo ""

  echo "fablo channel getinfo orgb-chain orgb peer0"
  echo -e "\t Get channel info on 'peer0' of 'orgB'".
  echo ""
  echo "fablo channel fetch config orgb-chain orgb peer0 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer0' of 'orgB'".
  echo ""
  echo "fablo channel fetch lastBlock orgb-chain orgb peer0 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer0' of 'orgB'".
  echo ""
  echo "fablo channel fetch firstBlock orgb-chain orgb peer0 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer0' of 'orgB'".
  echo ""

  echo "fablo channel getinfo orgb-chain orgb peer1"
  echo -e "\t Get channel info on 'peer1' of 'orgB'".
  echo ""
  echo "fablo channel fetch config orgb-chain orgb peer1 <fileName.json>"
  echo -e "\t Download latest config block to current dir. Uses first peer 'peer1' of 'orgB'".
  echo ""
  echo "fablo channel fetch lastBlock orgb-chain orgb peer1 <fileName.json>"
  echo -e "\t Download last, decrypted block to current dir. Uses first peer 'peer1' of 'orgB'".
  echo ""
  echo "fablo channel fetch firstBlock orgb-chain orgb peer1 <fileName.json>"
  echo -e "\t Download first, decrypted block to current dir. Uses first peer 'peer1' of 'orgB'".
  echo ""

}
