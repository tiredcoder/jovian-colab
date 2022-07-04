#!/usr/bin/env node

/*
 * Client app for testing ACL policies in Fabric
 * We test if we can access all blockchain events.
 *
 * Based in part on the "Commercial Paper" example:
 *  - https://github.com/hyperledger/fabric-samples/blob/6d043af4879d6be6adf4803bb3a29c80b4f2a895/commercial-paper/organization/magnetocorp/application/cpListener.js
 * 
 * Also see: https://hyperledger-fabric.readthedocs.io/en/release-2.4/access_control.html
 */

'use strict';

const yaml = require('js-yaml');
const { Wallets, Gateway } = require('fabric-network');
const path = require("path");
const fs = require("fs");
const minimist = require('minimist');

let finished;

async function main() {
  try {
    // Parse command line arguments
    const args = minimist(process.argv.slice(2));
    const walletPath = args['wallet'];
    const connectionProfileFile = args['profile'];
    const username = args['user'];
    const channel = args['channel'];

    // Greeting
    console.log(' --- Fabric ACL Policy Test Client Application --- ');

    // Verify existence of command line arguments
    if (walletPath == null || connectionProfileFile == null || username == null || channel == null) {
      console.error('Missing argument(s)!');
      console.log('Command usage: testPolicy.js --wallet <wallet directory> --profile <connection profile> --user <MSP identity in wallet> --channel <channel>');
      process.exit(1);
    }

    // Check to see if the wallet exists
    if (fs.existsSync(walletPath)) {
      // Wallet exists
      console.log(`Existing wallet found at "${walletPath}".`);
    } else {
      // No wallet found
      console.log(`Creating new wallet at "${walletPath}". You need to add the user's credentials (key pair) to this wallet.`);
    }

    // Set up the wallet
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    // Create a new gateway for connecting to our peer node.
    const gateway = new Gateway();

    // Load connection profile; will be used to locate a gateway
    let connectionProfile = yaml.load(fs.readFileSync(connectionProfileFile, 'utf8'));

    // Set connection options; identity and wallet
    let connectionOptions = {
        identity: username,
        wallet: wallet,
        discovery: { enabled:true, asLocalhost:false }
    };

    // connect to the gateway
    await gateway.connect(connectionProfile, connectionOptions);
        
    // get the channel
    const network = await gateway.getNetwork(channel);
    
    console.log(`Connected as user '${username}' and channel '${channel}' selected. Starting to listen for block events...`);

    // Listen for blocks being added, display relevant contents: in particular, the transaction inputs
    finished = false;
        
    const listener = async (event) => {
      if (event.blockData !== undefined) {
        for (const i in event.blockData.data.data) {
          if (event.blockData.data.data[i].payload.data.actions !== undefined) {
            const inputArgs = event.blockData.data.data[i].payload.data.actions[0].payload.chaincode_proposal_payload.input.chaincode_spec.input.args;
            // Print block details
            console.log('----------');
            console.log('Block:', parseInt(event.blockData.header.number), 'transaction', i);
            // Show ID and timestamp of the transaction
            const tx_id = event.blockData.data.data[i].payload.header.channel_header.tx_id;
            const txTime = new Date(event.blockData.data.data[i].payload.header.channel_header.timestamp).toUTCString();
            // Show ID, date and time of transaction
            console.log('Transaction ID:', tx_id);
            console.log('Timestamp:', txTime);
            // Show transaction inputs (formatted, as may contain binary data)
            let inputData = 'Inputs: ';
            for (let j = 0; j < inputArgs.length; j++) {
              const inputArgPrintable = inputArgs[j].toString().replace(/[^\x20-\x7E]+/g, '');
              inputData = inputData.concat(inputArgPrintable, ' ');
            }
            console.log(inputData);
            // Show the proposed writes to the world state
            let keyData = 'Keys updated: ';
            for (const l in event.blockData.data.data[i].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[1].rwset.writes) {
              // add a ' ' space between multiple keys in 'concat'
              keyData = keyData.concat(event.blockData.data.data[i].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[1].rwset.writes[l].key, ' ');
            }
            console.log(keyData);
            // Show which organizations endorsed
            let endorsers = 'Endorsers: ';
            for (const k in event.blockData.data.data[i].payload.data.actions[0].payload.action.endorsements) {
              endorsers = endorsers.concat(event.blockData.data.data[i].payload.data.actions[0].payload.action.endorsements[k].endorser.mspid, ' ');
            }
            console.log(endorsers);
            // Was the transaction valid or not?
            // (Invalid transactions are still logged on the blockchain but don't affect the world state)
            if ((event.blockData.metadata.metadata[2])[i] !== 0) {
              console.log('INVALID TRANSACTION');
            }
          }
        }
      }
    };
    const options = {
        type: 'full',
        startBlock: 1
    };
    await network.addBlockListener(listener, options);
    while (!finished) {
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
    gateway.disconnect();
  }
  catch (error) {
    console.error('Error: ', error);
    process.exit(1);
  }
}

void main();
