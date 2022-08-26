/*
 * IPFS Chaincode
 *
 * Based in part on the "Basic Asset Transfer" example:
 * https://github.com/hyperledger/fabric-samples/blob/72559dfbb51c8b2936a4a796accc656c19f41493/asset-transfer-basic/chaincode-javascript/lib/assetTransfer.js
 * 
 * Docs:
 *  - https://hyperledger.github.io/fabric-chaincode-node/release-2.2/api/index.html
 *  - https://hyperledger.github.io/fabric-chaincode-node/release-2.2/api/tutorial-using-iterators.html
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

  // Verify if the network or data with the given ID exists in world state
  async checkElementExists(ctx, id) {
    const elementJSON = await ctx.stub.getState(id);
    return elementJSON && elementJSON.length > 0;
  }

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

  // Verify if the user has access to the data (because they're the owner or in the access list)
  async checkAccess(owner, acl, perms) {
    const userIdMsp = this.clientCertCN + '@' + this.clientMSPId; // User identity, with MSP, that invoked the chaincode
    if (perms.includes(acl.Users[userIdMsp])) return true; // User is in the ACL and has the specified permission(s)
    if (perms.includes(acl.MSPs[this.clientMSPId])) return true; // User's MSP is in the ACL and has the specified permission(s)
    if (owner.ID === this.clientCertCN && owner.MSPId === this.clientMSPId) return true; // User is the owner
    if (this.clientCert.subject.includes('OU=admin')) return true; // Make an exception for the admin
    return false; // No access
  }

  async beforeTransaction(ctx) {
    // Populate attributes
    this.clientId = new ClientIdentity(ctx.stub);
    this.clientMSPId = this.clientId.getMSPID();
    this.clientCert = new X509Certificate(this.clientId.getIDBytes());
    this.clientCertCN = this.clientCert.subject.split('\n').filter(cn => cn.includes('CN=')).toString().slice(3);

    // Verifiy if IPFS user
    const userIPFS = await this.checkUserIPFS();
    if(!userIPFS) throw new Error(`User is not enabled for IPFS usage (IPFS attribute is missing in certificate).`);
  }

  /*
   * !!! IPFS networks !!!
   */

  // Add an IPFS network description
  async createNetwork(ctx, id, bootstrapNodes, netKey, pinningSvcs, relays, acl) {
    // Only admins can add IPFS network descriptions
    if (!this.clientCert.subject.includes('OU=admin')) {
      throw new Error(`Only admins can add IPFS network descriptions. You are: '${this.clientCertCN}@${this.clientMSPId}'.`);
    }

    // Set key to <MSP>/networks/0/<network>
    const key = this.clientMSPId + '/networks/0/' + id;

    // Verify existence
    const exists = await this.checkElementExists(ctx, key);
    if (exists) throw new Error(`The IPFS network '${key}' already exists`);

    const owner = {
      MSPId: this.clientMSPId,
      ID: this.clientCertCN
    };

    const network = {
      ID: id,
      Owner: owner,
      BootstrapNodes: bootstrapNodes,
      NetKey: netKey,
      ClusterPinningService: JSON.parse(pinningSvcs),
      Relays: relays,
      ACL: JSON.parse(acl)
    };

    // Insert data in alphabetic order using 'json-stringify-deterministic' and 'sort-keys-recursive'
    const result = JSON.stringify(sortKeysRecursive(network));
    await ctx.stub.putState(key, Buffer.from(result));
    return result;
  }

  // Get all IPFS network descriptions (for the user's MSP if MSP not given)
  async listAllNetworks(ctx, mspId = this.clientMSPId) {
    // Set range of query
    const startKey = mspId + '/networks/0/';
    const endKey = mspId + '/networks/1/';
    let results = [];
    let accessError = false;

    for await (const {key, value} of ctx.stub.getStateByRange(startKey, endKey)) {
      const networkAsBytes = Buffer.from(value);
      let networkJSON = JSON.parse(networkAsBytes.toString());

      // Only ACL entries and the owner can get network info
      const access = await this.checkAccess(networkJSON.Owner, networkJSON.ACL, ['r','ro','rw']);
      if (!access) {
        accessError = true;
        continue;
      }

      // Only the owner can retrieve the ACL info
      if (networkJSON.Owner.ID !== this.clientCertCN || networkJSON.Owner.MSPId !== this.clientMSPId) delete networkJSON['ACL'];
      
      results.push(networkJSON);
    }

    if (accessError) results.push({"Errors":"Access denied. User lacks permission to read (some) network(s)."});

    const result = JSON.stringify(results);
    return result;
  }

  // Get an IPFS network description
  async readNetwork(ctx, key) {
    // Handle keys without 0 marker (i.e. 'orga/networks/net1' instead of 'orga/networks/0/net1')
    const keyElements = key.split(/(\/)/); // Split and preserve delimiter (/)
    if (keyElements[4] !== '0' ) key = keyElements.slice(0,4).join('') + '0/' + keyElements.slice(4).join('');

    // Get current state
    const networkAsBytes = await ctx.stub.getState(key);

    // Verify existence
    if (!networkAsBytes || networkAsBytes.length === 0) throw new Error(`The IPFS network description '${key}' does not exist`);

    let networkJSON = JSON.parse(networkAsBytes.toString());

    // Only ACL entries and the owner can get network info
    const access = await this.checkAccess(networkJSON.Owner, networkJSON.ACL, ['r','ro','rw']);
    if (!access) throw new Error(`Access denied. User lacks permission to read network '${key}'.`);

    // Only the owner can retrieve the ACL info
    if (networkJSON.Owner.ID !== this.clientCertCN || networkJSON.Owner.MSPId !== this.clientMSPId) delete networkJSON['ACL'];
    
    const result = JSON.stringify(networkJSON);
    return result;
  }
  
  // Delete an IPFS network description
  async deleteNetwork(ctx, key) {
    // Handle keys without 0 marker (i.e. 'orga/networks/net1' instead of 'orga/networks/0/net1')
    const keyElements = key.split(/(\/)/); // Split and preserve delimiter (/)
    if (keyElements[4] !== '0' ) key = keyElements.slice(0,4).join('') + '0/' + keyElements.slice(4).join('');

    // Get current state
    const networkAsBytes = await ctx.stub.getState(key);
    
    // Verify existence
    if (!networkAsBytes || networkAsBytes.length === 0) throw new Error(`The IPFS network '${key}' does not exist`);

    // Only the owner or an ACL user with write access can delete a network
    const networkJSON = JSON.parse(networkAsBytes.toString());
    const access = await this.checkAccess(networkJSON.Owner, networkJSON.ACL, ['rw','w']);
    if (!access) throw new Error(`Access denied. User lacks permission to delete network '${key}'.`);

    const result = await ctx.stub.deleteState(key);
    return result;
  }

  /*
   * !!! Data (IPFS CIDs refering to files and directories) !!!
   */

  // Add a data description
  async createData(ctx, id, networkId, cid, cryptCipher, cryptKey, acl) {
    // Set key to <user>@<MSP>/0/<data>
    const key = this.clientCertCN + '@' + this.clientMSPId + '/0/' + id;

    // Verify existence
    const exists = await this.checkElementExists(ctx, key);
    if (exists) throw new Error(`The data description at '${key}' already exists`);

    const owner = {
      MSPId: this.clientMSPId,
      ID: this.clientCertCN
    };

    const data = {
      ID: id,
      Owner: owner,
      NetworkId: networkId,
      CID: cid,
      CryptCipher: cryptCipher,
      CryptKey: cryptKey,
      ACL: JSON.parse(acl)
    };

    // Insert data in alphabetic order using 'json-stringify-deterministic' and 'sort-keys-recursive'
    const result = JSON.stringify(sortKeysRecursive(data));
    await ctx.stub.putState(key, Buffer.from(result));
    return result;
  }

  // Get all data descriptions (for the current user if user not given)
  async listAllData(ctx, user = this.clientCertCN + '@' + this.clientMSPId) {
    // Set range of query
    const startKey = user + '/0/';
    const endKey = user + '/1/';
    let results = [];
    let accessError = false;

    for await (const {key, value} of ctx.stub.getStateByRange(startKey, endKey)) {
      const dataAsBytes = Buffer.from(value);
      let dataJSON = JSON.parse(dataAsBytes.toString());

      // Only ACL entries and the owner can get data info
      const access = await this.checkAccess(dataJSON.Owner, dataJSON.ACL, ['r','ro','rw']);
      if (!access) {
        accessError = true;
        continue;
      }

      // Only the owner can retrieve the ACL info
      if (dataJSON.Owner.ID !== this.clientCertCN || dataJSON.Owner.MSPId !== this.clientMSPId) delete dataJSON['ACL'];

      results.push(dataJSON);
    }

    if (accessError) results.push({"Errors":"Access denied. User lacks permission to read (some) data."});

    const result = JSON.stringify(results);
    return result;
  }

  // Get a data description
  async readData(ctx, key) {
    // Handle keys without 0 marker (i.e. 'user@msp/filename' instead of 'user@msp/0/filename')
    const keyElements = key.split(/(\/)/); // Split and preserve delimiter (/)
    if (keyElements[2] !== '0' ) key = keyElements.slice(0,2).join('') + '0/' + keyElements.slice(2).join('');

    // Get current state
    const dataAsBytes = await ctx.stub.getState(key);

    // Verify existence
    if (!dataAsBytes || dataAsBytes.length === 0) throw new Error(`The data description at '${key}' does not exist`);

    let dataJSON = JSON.parse(dataAsBytes.toString());

    // Only ACL entries and the owner can get data info
    const access = await this.checkAccess(dataJSON.Owner, dataJSON.ACL, ['r','ro','rw']);
    if (!access) throw new Error(`Access denied. User lacks permission to read data at '${key}'.`);

    // Only the owner can retrieve the ACL info
    if (dataJSON.Owner.ID !== this.clientCertCN || dataJSON.Owner.MSPId !== this.clientMSPId) delete dataJSON['ACL'];

    const result = JSON.stringify(dataJSON);
    return result;
  }

  // Delete a data description
  async deleteData(ctx, key) {
    // Handle keys without 0 marker (i.e. 'user@msp/filename' instead of 'user@msp/0/filename')
    const keyElements = key.split(/(\/)/); // Split and preserve delimiter (/)
    if (keyElements[2] !== '0' ) key = keyElements.slice(0,2).join('') + '0/' + keyElements.slice(2).join('');

    // Get current state
    const dataAsBytes = await ctx.stub.getState(key);

    // Verify existence
    if (!dataAsBytes || dataAsBytes.length === 0) throw new Error(`The data description at '${key}' does not exist`);

    // Only the owner or an ACL user with write access can delete the data
    const dataJSON = JSON.parse(dataAsBytes.toString());
    const access = await this.checkAccess(dataJSON.Owner, dataJSON.ACL, ['rw','w']);
    if (!access) throw new Error(`Access denied. User lacks permission to delete data at '${key}'.`);

    const result = await ctx.stub.deleteState(key);
    return result;
  }

  // Get the history of a data description
  async listDataHistory(ctx, key) {
    // Handle keys without 0 marker (i.e. 'user@msp/filename' instead of 'user@msp/0/filename')
    const keyElements = key.split(/(\/)/); // Split and preserve delimiter (/)
    if (keyElements[2] !== '0' ) key = keyElements.slice(0,2).join('') + '0/' + keyElements.slice(2).join('');

    let results = [];
    let accessError = false;

    for await (const keyMod of ctx.stub.getHistoryForKey(key)) {
      // Ignore deletions (i.e. only get transactions with values)
      if (!keyMod.isDelete) {
        const dataAsBytes = Buffer.from(keyMod.value);
        let dataJSON = JSON.parse(dataAsBytes.toString());

        // Only ACL entries and the owner can get data info
        const access = await this.checkAccess(dataJSON.Owner, dataJSON.ACL, ['r','ro','rw']);
        if (!access) {
          accessError = true;
          continue;
        }

        // Only the owner can retrieve the ACL info
        if (dataJSON.Owner.ID !== this.clientCertCN || dataJSON.Owner.MSPId !== this.clientMSPId) delete dataJSON['ACL'];

        const timestampSeconds = keyMod.timestamp.seconds.toNumber() + (keyMod.timestamp.nanos / 1000000000);

        const dataHistory = {
          TxID: keyMod.txId,
          Timestamp: timestampSeconds,
          Data: dataJSON
        }

        results.push(dataHistory);
      }
    }

    if (accessError) results.push({"Errors":"Access denied. User lacks permission to read (some) data."});

    const result = JSON.stringify(results);
    return result;
  }

};

module.exports = IPFSContract;
