#!/usr/bin/env node

/*
 * Client app for registering identities in Fabric CA
 *
 * Based in part on the "Commercial Paper" example:
 *  - https://github.com/hyperledger/fabric-samples/tree/main/commercial-paper
 *  - https://hyperledger-fabric.readthedocs.io/en/release-2.4/tutorial/commercial_paper.html
 * 
 * Also see: https://hyperledger-fabric-ca.readthedocs.io/en/latest/deployguide/use_CA.html#overview-of-registration-and-enrollment
 */

'use strict';

// Include modules
const { Wallets, x509Identity } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const yaml = require('js-yaml');
const fs = require('fs');
const readline = require('readline');
const minimist = require('minimist');

// Enroll the CA admin (who can register users)
async function enrollAdmin(wallet, adminUsername, connectionProfileFile, organization) {
  console.log(`Enrolling CA admin user "${adminUsername}" of organization "${organization}"`);
  try {
    // Each organization has its own CA admin user
    const adminUsernameOrg = `${adminUsername}-${organization}`;

    // Check to see if a CA admin user identity already exists in the wallet
    const adminIdentity = await wallet.get(adminUsernameOrg);
    if (adminIdentity) {
      throw `An identity for the CA admin user ${adminUsername} of organization "${organization}" already exists in the wallet`;
    }

    // Load the network configuration
    let connectionProfile = yaml.safeLoad(fs.readFileSync(connectionProfileFile, 'utf8'));

    // Create a new CA client for interacting with the CA
    try {
      var certAuth = connectionProfile.organizations[organization].certificateAuthorities[0];
    } catch {
      throw `No certificate authority found for organization "${organization}" in connection profile "${connectionProfileFile}"`;
    }
    const caInfo = connectionProfile.certificateAuthorities[certAuth];
    const caTLSCACerts = caInfo.tlsCACerts.pem;
    const ca = new FabricCAServices(caInfo.url, { trustedRoots: caTLSCACerts, verify: false }, caInfo.caName);

    // Ask for the CA admin user's password
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    const adminPassword = await new Promise(resolve => {
      rl.question("CA admin user password? ", resolve)
    });
    rl.close();

    // Check if the CA admin user's password has been given
    if (adminPassword == null || adminPassword.length < 1) {
      throw 'CA admin user password not given!';
    }
    
    // Enroll the CA admin user
    const enrollment = await ca.enroll({ enrollmentID: adminUsername, enrollmentSecret: adminPassword });
    console.log(`Successfully enrolled the CA admin user "${adminUsername}" of organization "${organization}"`);

    // Import the identity of the enrolled CA admin user into the wallet
    const mspId = connectionProfile.organizations[organization].mspid;
    const x509Identity = {
      credentials: {
        certificate: enrollment.certificate,
        privateKey: enrollment.key.toBytes(),
      },
      mspId: mspId,
      type: 'X.509',
    };
    await wallet.put(adminUsernameOrg, x509Identity);
    console.log(`Successfully imported identity of CA admin user "${adminUsername}" of organization "${organization}" into the wallet`);
  
  } catch (error) {
    console.error(`Failed to enroll CA admin user "${adminUsername}" of organization "${organization}": ${error}`);
    process.exit(3);
  }
}

// Register a user
async function registerUser(wallet, adminUsername, connectionProfileFile, organization, username) {
  console.log(`Registering user "${username}" in organization "${organization}"`);
  try {
    // Each organization has its own CA admin user
    const adminUsernameOrg = `${adminUsername}-${organization}`;

    // Check to see if a CA admin user identity exists in the wallet
    var adminIdentity = await wallet.get(adminUsernameOrg);
    while (!adminIdentity) {
      // Enroll the CA admin user if no identity exists in the wallet
      console.log(`An identity for the CA admin user "${adminUsername}" of organization "${organization}" does not exists in the wallet`);
      await enrollAdmin(wallet, adminUsername, connectionProfileFile, organization);
      adminIdentity = await wallet.get(adminUsernameOrg);
    }

    // Build a CA admin user object for authenticating with the CA
    const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
    const adminUser = await provider.getUserContext(adminIdentity, adminUsername);

    // Load the network configuration
    let connectionProfile = yaml.safeLoad(fs.readFileSync(connectionProfileFile, 'utf8'));

    // Create a new CA client for interacting with the CA
    try {
      var certAuth = connectionProfile.organizations[organization].certificateAuthorities[0];
    } catch {
      throw `No certificate authority found for organization "${organization}" in connection profile "${connectionProfileFile}"`;
    }
    const caInfo = connectionProfile.certificateAuthorities[certAuth];
    const caTLSCACerts = caInfo.tlsCACerts.pem;
    const ca = new FabricCAServices(caInfo.url, { trustedRoots: caTLSCACerts, verify: false }, caInfo.caName);

    // Register the user
    const user = {
      enrollmentID: username,
      affiliation: '',
      role: 'client',
      attrs: [
        { "name": "ipfs", "value": "true", "ecert": true }
      ]
    };
    const secret = await ca.register(user, adminUser);
    console.log(`Successfully registered user "${username}" in organization "${organization}"`);
    console.log(`Secret of user "${username}": "${secret}"`);
    console.log('***SECURITY NOTE***: The secret is normally not visible to the CA admin (i.e. the secret is *only* send to the user)!');

  } catch (error) {
    console.error(`Failed to register user "${username}": ${error}`);
    process.exit(2);
  }
}

// Program entrypoint
async function main() {
  // Parse command line arguments
  const args = minimist(process.argv.slice(2));
  const connectionProfileFile = args['profile'];
  const organization = args['org'];
  const username = args['user'];
  var walletPath = args['wallet'];
  var adminUsername = args['admin'];

  // Greeting
  console.log(' --- Fabric CA Client Application --- ');

  // Verify existence of command line arguments
  if (connectionProfileFile == null || organization == null || username == null) {
    console.error('Missing argument(s)!');
    console.log('Command usage: registerUser.js --wallet <wallet directory> --admin <CA admin name> --profile <connection profile> --org <organization> --user <username to register>');
    process.exit(1);
  }

  // Use defaults if not provided
  if (walletPath == null) {
    walletPath = './wallet';
  }
  if (adminUsername == null) {
    adminUsername = 'admin';
  }

  // Check to see if the wallet exists
  if (fs.existsSync(walletPath)) {
    // Wallet exists
    console.log(`Existing wallet found at "${walletPath}"`);
  } else {
    // No wallet found
    console.log(`Creating new wallet at "${walletPath}"`);
  }

  // Open/Create the wallet  
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  // Register the user
  registerUser(wallet, adminUsername, connectionProfileFile, organization, username);
}

main();
