/*
 * IPFS Chaincode
 *
 * Based in part on the "Basic Asset Transfer" example:
 * https://github.com/hyperledger/fabric-samples/blob/72559dfbb51c8b2936a4a796accc656c19f41493/asset-transfer-basic/chaincode-javascript/lib/assetTransfer.js
 * 
 */

'use strict';

// Include modules
const { Contract } = require('fabric-contract-api');
const ClientIdentity = require('fabric-shim').ClientIdentity;
const stringify = require('json-stringify-deterministic');
const sortKeysRecursive = require('sort-keys-recursive');
const X509Certificate = require("crypto").X509Certificate;

// Create contract
class IPFSContract extends Contract {
  constructor() {
    super('IPFSContract');

    // Attributes
    this.clientId = {};
    this.clientMSPId = "";
    this.clientCert = "";
    this.clientCertCN = "";
  }

  // Populate attributes
  async beforeTransaction(ctx) {
    this.clientId = new ClientIdentity(ctx.stub);
    this.clientMSPId = this.clientId.getMSPID();
    this.clientCert = new X509Certificate(this.clientId.getIDBytes());
    this.clientCertCN = this.clientCert.subject.split('\n').filter(cn => cn.includes('CN=')).toString().slice(3);

    //console.log(`clientMSPId: ${this.clientMSPId}`);
    //console.log(`clientCertCN: ${this.clientCertCN}`);
  }

  // Verify if the network or data with the given ID exists in world state
  async checkElementExists(ctx, id) {
    const elementJSON = await ctx.stub.getState(id);
    return elementJSON && elementJSON.length > 0;
  }

  /*
   * !!! IPFS networks !!!
   */

  //add: networks: name, key, bootstrapnodes, acl


  // Verify if the user has the 'IPFS' attribute set in their certificate
  async checkUserIPFS() {
    if (!this.clientId.assertAttributeValue('ipfs', 'true')) {
      // Make an exception for the admin
      if (!this.clientCert.subject.includes('OU=admin')) {
        return false;
      }
    }
    return true;
  }

  // Add an IPFS network description
  async addNetwork(ctx, id, bootstrapNodes, netKey, acl) {
    // Only admins can add IPFS network descriptions
    //if (!this.clientCert.subject.includes('OU=admin')) {
    //  throw new Error(`Only admins can add IPFS network descriptions.`);
    //}

    // Verify existence
    const exists = await this.checkElementExists(ctx, id);
    if (exists) {
      throw new Error(`The IPFS network description with ID '${id}' already exists`);
    }

    const owner = {
      MSPId: this.clientMSPId,
      ID: this.clientCertCN,
    };

    const network = {
      ID: id,
      Owner: owner,
      BootstrapNodes: bootstrapNodes,
      NetKey: netKey,
      ACL: acl,
    };

    // Insert data in alphabetic order using 'json-stringify-deterministic' and 'sort-keys-recursive'
    const result = JSON.stringify(sortKeysRecursive(network));
    await ctx.stub.putState(id, Buffer.from(result));
    return result;
  }

  // Get an IPFS network description
  async getNetwork(ctx, id) {
    // Verifiy if IPFS user
    const userIPFS = await this.checkUserIPFS();
    if(!userIPFS) {
      throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
    }

    // Get current state
    const networkAsBytes = await ctx.stub.getState(id);

    // Verify existence
    if (!networkAsBytes || networkAsBytes.length === 0) {
      throw new Error(`The IPFS network description with ID '${id}' does not exist`);
    }

    // Only ACL users and owner can get network info
    const networkJSON = JSON.parse(networkAsBytes.toString());
    console.log(`owner: ${networkJSON.Owner}`);
    console.log(`clientCertCN: ${networkJSON.Owner.clientCertCN}`);
    
    return networkJSON;
  }
  
  // Delete an IPFS network description
  async delNetwork(ctx, id) {
    // Verifiy if IPFS user
    const userIPFS = await this.checkUserIPFS();
    if(!userIPFS) {
      throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
    }

    // Get current state
    const networkAsBytes = await ctx.stub.getState(id);
    
    // Verify existence
    if (!networkAsBytes || networkAsBytes.length === 0) {
      throw new Error(`The IPFS network description with ID '${id}' does not exist`);
    }

    // Only the owner can delete
    const networkJSON = JSON.parse(networkAsBytes.toString());
    console.log(`owner: ${networkJSON.Owner}`);

    await ctx.stub.deleteState(id);
  }

  /*
   * !!! Data (IPFS CIDs refering to files and directories) !!!
   */

  // Add a data description
  async addData(ctx, id, owner, networkId, cid, cryptKey, acl) {
    // Verifiy if IPFS user
    const userIPFS = await this.checkUserIPFS();
    if(!userIPFS) {
      throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
    }

    // Verify existence
    const exists = await this.checkElementExists(ctx, id);
    if (exists) {
      throw new Error(`The data description with ID '${id}' already exists`);
    }

    const data = {
      ID: id,
      Owner: owner,
      NetworkId: networkId,
      CID: cid,
      CryptKey: cryptKey,
      ACL: acl,
    };

    // Insert data in alphabetic order using 'json-stringify-deterministic' and 'sort-keys-recursive'
    await ctx.stub.putState(id, Buffer.from(stringify(sortKeysRecursive(data))));
    return JSON.stringify(data);
  }

  // Get a data description
  async getData(ctx, id) {
    // Verifiy if IPFS user
    const userIPFS = await this.checkUserIPFS();
    if(!userIPFS) {
      throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
    }

    // Get current state
    const dataAsBytes = await ctx.stub.getState(id);

    // Verify existence
    if (!dataAsBytes || dataAsBytes.length === 0) {
      throw new Error(`The data description with ID '${id}' does not exist`);
    }

    // Only ACL users and owner can get data info
    const dataJSON = JSON.parse(dataAsBytes.toString());
    console.log(`owner: ${dataJSON.Owner}`);

    return dataJSON;
  }

  // Delete a data description
  async delData(ctx, id) {
    // Verifiy if IPFS user
    const userIPFS = await this.checkUserIPFS();
    if(!userIPFS) {
      throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
    }

    // Get current state
    const dataAsBytes = await ctx.stub.getState(id);

    // Verify existence
    if (!dataAsBytes || dataAsBytes.length === 0) {
      throw new Error(`The data description with ID '${id}' does not exist`);
    }

    // Only the owner can delete
    const dataJSON = JSON.parse(dataAsBytes.toString());
    console.log(`owner: ${dataJSON.Owner}`);

    await ctx.stub.deleteState(id);
  }
};

module.exports = IPFSContract;
