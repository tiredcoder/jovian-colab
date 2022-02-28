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

// Create contract
class IPFSContract extends Contract {
  constructor() {
    super('IPFSContract');

    // Attributes
    this.clientId = {};
    this.clientMSPId = ""
    this.clientCert = "";
  }

  // Populate attributes
  async beforeTransaction(ctx) {
    this.clientId = new ClientIdentity(ctx.stub);
    this.clientMSPId = this.clientId.getMSPID();
    this.clientCert = this.clientId.getID();
  }

  // Verify if the network or data with the given ID exists in world state
  async checkElementExists(ctx, id) {
    const elementJSON = await ctx.stub.getState(id);
    return elementJSON && elementJSON.length > 0;
  }

  /*
   * !!! IPFS networks !!!
   */

  // Add an IPFS network description
  async addNetwork(ctx, id, owner, bootstrapNodes, netKey, acl) {
    // Only admins can add IPFS network descriptions
    if (!this.clientId.assertAttributeValue('OU', 'admin')) {
      throw new Error(`Only admins can add IPFS network descriptions. You are: ${this.clientCert}`);
    }

    // Verify existence
    const exists = await this.checkElementExists(ctx, id);
    if (exists) {
      throw new Error(`The IPFS network description with ID '${id}' already exists`);
    }

    const network = {
      ID: id,
      Owner: owner,
      BootstrapNodes: bootstrapNodes,
      NetKey: netKey,
      ACL: acl,
    };

    // Insert data in alphabetic order using 'json-stringify-deterministic' and 'sort-keys-recursive'
    await ctx.stub.putState(id, Buffer.from(stringify(sortKeysRecursive(network))));
    return JSON.stringify(network);
  }

  // Get an IPFS network description
  async getNetwork(ctx, id) {
    // Only ACL users and owner can get network info

    // Verify existence
    const networkJSON = await ctx.stub.getState(id);
    if (!networkJSON || networkJSON.length === 0) {
      throw new Error(`The IPFS network description with ID '${id}' does not exist`);
    }

    return networkJSON.toString();
  }
  
  // Delete an IPFS network description
  async delNetwork(ctx, id) {
    // Only the owner can delete

    // Verify existence
    const exists = await this.checkElementExists(ctx, id);
    if (!exists) {
      throw new Error(`The IPFS network description with ID '${id}' does not exist`);
    }

    await ctx.stub.deleteState(id);
  }

  /*
   * !!! Data (IPFS CIDs refering to files and directories) !!!
   */

  // Add a data description
  async addData(ctx, id, owner, networkId, cid, cryptKey, acl) {
    // Verify if the user has the 'IPFS' attribute set in their certificate
    if (!this.clientId.assertAttributeValue('ipfs', 'true')) {
      // Make an exception for the admin
      if (!this.clientId.assertAttributeValue('OU', 'admin')) {
        throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
      }
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
    // Only ACL users and owner can get data info

    // Verify existence
    const dataJSON = await ctx.stub.getState(id);
    if (!dataJSON || dataJSON.length === 0) {
      throw new Error(`The data description with ID '${id}' does not exist`);
    }

    return dataJSON.toString();
  }

  // Delete a data description
  async delData(ctx, id) {
    // Only the owner can delete

    // Verify existence
    const exists = await this.checkElementExists(ctx, id);
    if (!exists) {
      throw new Error(`The data description with ID '${id}' does not exist`);
    }

    await ctx.stub.deleteState(id);
  }
};

module.exports = IPFSContract;
