/*
 * Functions to interact with the Hyperledger Fabric blockchain (using the Fabric Gateway SDK)
 *
 * Docs:
 *  https://hyperledger.github.io/fabric-gateway/
 *  https://hyperledger.github.io/fabric-gateway/migration
 *  https://hyperledger.github.io/fabric-gateway/main/api/node/
 *  
 * Based in part on the "Basic Asset Transfer" example:
 *  https://github.com/hyperledger/fabric-samples/tree/fee6a44fcd3610ba612a6c0455e98642183eff24/asset-transfer-basic/application-gateway-typescript
 *
*/
'use strict';
import * as path from 'path';
import fsp from 'fs/promises';
import fs from 'fs';
import YAML from 'yaml';
import FabricCAServices from 'fabric-ca-client';
import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import { Gateway, Network, connect, Contract, Identity, Signer, signers } from '@hyperledger/fabric-gateway';
import { TextDecoder } from 'util';

interface Config {
  organization: string;
  mspId: string;
  identity: string;
  idCertFile: string;
  idKeyFile: string;
  caEndpoint: string;
  caTlsRootCertFile: string;
  caName: string;
  gatewayEndpoint: string;
  gatewayTlsCertFile: string;
  caTlsVerify: boolean;
  gatewayHostAlias: string;
  channel: string;
  chaincode: string;
}

interface connectionDetails {
  gRpcClient: grpc.Client;
  gateway: Gateway;
  contract: Contract;
}

function EnvOrConfigOrError(envVariableName: string, configFileValue: string): string {
  const envVariableValue: string|undefined = process.env[envVariableName];
  if (typeof envVariableValue !== 'undefined') return envVariableValue;
  if (typeof configFileValue !== 'undefined') return configFileValue;
  throw new Error('Missing configuration'); 
}

const parseConfig = async (configFile?: string, organization?: string): Promise<Config> => {
  console.log(`Configuration File: ${configFile}`);
  try {
    // Load config file
    const content = configFile ? await YAML.parse(await fsp.readFile(path.resolve(configFile),'utf8')) : undefined;
    if (typeof content == 'undefined') console.log('Warning: No config file provided! Trying to use environment only.');

    // Set organization (env > CLI arg > config file)
    const org: string|undefined = process.env['FABRIC_ORG'] || organization || (content ? content.defaultOrg : undefined);
    if (typeof org == 'undefined') throw new Error('Organization is not specified');

    // Set config (env > config file )
    const config: Config = {
      organization: org,
      mspId: EnvOrConfigOrError('FABRIC_MSPID', content ? content.organizations[org].mspid : undefined),
      identity: EnvOrConfigOrError('FABRIC_ID', content ? content.organizations[org].identity : undefined ),
      idCertFile: EnvOrConfigOrError('FABRIC_ID_CERT', content ? content.identities[content.organizations[org].identity].cert.path : undefined ),
      idKeyFile: EnvOrConfigOrError('FABRIC_ID_KEY', content ? content.identities[content.organizations[org].identity].key.path : undefined ),
      caEndpoint: EnvOrConfigOrError('FABRIC_CA', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].url : undefined),
      caTlsRootCertFile: EnvOrConfigOrError('FABRIC_CA_CERT', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].tlsCACerts.path : undefined),
      caTlsVerify: Boolean(EnvOrConfigOrError('FABRIC_CA_VERIFY', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].httpOptions.verify : undefined)),
      caName: EnvOrConfigOrError('FABRIC_CA_NAME', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].caName : undefined),
      gatewayEndpoint: EnvOrConfigOrError('FABRIC_GATEWAY', content ? content.gateways[content.organizations[org].gateway].url : undefined),
      gatewayTlsCertFile: EnvOrConfigOrError('FABRIC_GATEWAY_CERT', content ? content.gateways[content.organizations[org].gateway].tlsCACerts.path : undefined),
      gatewayHostAlias: EnvOrConfigOrError('FABRIC_GATEWAY_HOST_ALIAS', content ? content.gateways[content.organizations[org].gateway].grpcOptions['ssl-target-name-override'] : undefined),
      channel: EnvOrConfigOrError('FABRIC_CHANNEL', content ? content.organizations[org].defaultChannel : undefined),
      chaincode: EnvOrConfigOrError('FABRIC_CHAINCODE', content ? content.organizations[org].defaultChaincode : undefined)
    }
    return config;
  } catch (error) {
    throw new Error(`Config error: ${error}`); 
  }
}

const fileExists = async (file: string): Promise<boolean> => {
  try {
    await fsp.access(path.resolve(file), fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

const enroll = async (identity: string, idCertFile: string, idKeyFile: string, secret: string, caEndpoint: string, caTlsRootCertFile: string, caTlsVerify: boolean, caName: string): Promise<void> => {
  try {
    // Don't enroll if credentials already exist
    if (await fileExists(idCertFile)) throw new Error(`file '${idCertFile}' exists`);
    if (await fileExists(idKeyFile)) throw new Error(`file '${idKeyFile}' exists`);
    
    // Read TLS root CA
    const caTlsRootCert: Buffer = await fsp.readFile(path.resolve(caTlsRootCertFile));

    // Enroll the user
    const ca = new FabricCAServices(caEndpoint, { trustedRoots: caTlsRootCert, verify: caTlsVerify }, caName);
    const enrollment = await ca.enroll({ enrollmentID: identity, enrollmentSecret: secret });
    
    // Save credentials to disk (also create dir if it doesn't exists)
    const idCertFileDir = path.dirname(path.resolve(idCertFile));
    await fsp.mkdir(idCertFileDir, { recursive: true });
    await fsp.writeFile(path.resolve(idCertFile), enrollment.certificate);
    const idKeyFileDir = path.dirname(path.resolve(idKeyFile));
    await fsp.mkdir(idKeyFileDir, { recursive: true });
    await fsp.writeFile(path.resolve(idKeyFile), enrollment.key.toBytes());
  } catch (error) {
    console.error(`Failed to enroll user : ${error}`);
  }
}

const newGrpcConnection = async (gatewayEndpoint: string, gatewayTlsCertFile: string, gatewayHostAlias: string): Promise<grpc.Client> => {
  const tlsRootCert = await fsp.readFile(path.resolve(gatewayTlsCertFile));
  const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
  return new grpc.Client(gatewayEndpoint, tlsCredentials, {
      'grpc.ssl_target_name_override': gatewayHostAlias,
  });
}

const createGatewayIdentity = async (mspId: string, idCertFile: string): Promise<Identity> => {
  const credentials = await fsp.readFile(path.resolve(idCertFile));
  return { mspId, credentials };
}

const createGatewaySigner = async (idKeyFile: string): Promise<Signer> => {
  const privateKeyPem = await fsp.readFile(path.resolve(idKeyFile));
  const privateKey = crypto.createPrivateKey(privateKeyPem);
  return signers.newPrivateKeySigner(privateKey);
}

const getConfig = async (configFile: string, organization?: string): Promise<Config> => {
  // Parse config (from environment vars or file)
  const config: Config = configFile ?
    (organization ?
      await parseConfig(configFile, organization) // Config file and org given
      :
      await parseConfig(configFile)               // Config file without org given
    )
    :
    (organization ? 
      await parseConfig(undefined, organization)  // Only org given
      :
      await parseConfig()                         // No config file or org given (use env only)
    ); 
  return config;
}

const execEnroll = async (config: Config, secret: string): Promise<void> => {
  console.log(' Enrolling... ');
  await enroll(config.identity, config.idCertFile, config.idKeyFile, secret, config.caEndpoint, config.caTlsRootCertFile, config.caTlsVerify, config.caName);
  console.log('Enrollment complete!');
}

const createConnection = async (config: Config): Promise<connectionDetails> => {
  try {
    // Create gRPC connection
    const gRpcClient: grpc.Client = await newGrpcConnection(config.gatewayEndpoint, config.gatewayTlsCertFile, config.gatewayHostAlias);

    // Identity
    const identity: Identity = await createGatewayIdentity(config.mspId, config.idCertFile);
    const signer: Signer = await createGatewaySigner(config.idKeyFile);

    // Connect to the gateway
    const gateway: Gateway = connect({identity, signer, client: gRpcClient});
    
    // Get the channel and chaincode
    const network: Network = gateway.getNetwork(config.channel);
    const contract: Contract = network.getContract(config.chaincode);

    // Return the connection details
    const connectionDetails: connectionDetails = {
      gRpcClient,
      gateway,
      contract
    };
    return connectionDetails;
  } catch (error) {
    throw new Error(`Connection creation error: ${error}`); 
  }
}

const closeConnection = async (gateway: Gateway, gRpcClient: grpc.Client): Promise<void> => {
  gateway.close();
  gRpcClient.close();
}


// IPFS Chaincode funtions
const createNetwork = async (contract: Contract, id: string, bootstrapNodes: string, netKey: string, pinningSvcs: string, acl: string): Promise<string> => {
  try {
    const responseBytes = await contract.submitTransaction('createNetwork', id, bootstrapNodes, netKey, pinningSvcs, acl);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const listAllNetworks = async (contract: Contract, mspId: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('listAllNetworks', mspId);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const readNetwork = async (contract: Contract, key: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('readNetwork', key);  
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const deleteNetwork = async (contract: Contract, key: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('deleteNetwork', key);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const createData = async (contract: Contract, id: string, networkId: string, cid: string, cryptCipher: string, cryptKey: string, chunkSize: string, acl: string): Promise<string> => {
  try {
    const responseBytes = await contract.submitTransaction('createData', id, networkId, cid, cryptCipher, cryptKey, chunkSize, acl);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const listAllData = async (contract: Contract, user: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('listAllData', user);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const readData = async (contract: Contract, key: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('readData', key);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const deleteData = async (contract: Contract, key: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('deleteData', key);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

const listDataHistory = async (contract: Contract, key: string): Promise<string> => {
  try {
    const responseBytes = await contract.evaluateTransaction('listDataHistory', key);
    const utf8Decoder = new TextDecoder();
    const responseJson: string = utf8Decoder.decode(responseBytes);
    return responseJson;
  } catch (error) {
    throw new Error(`Fabric Gateway error: ${error}`);
  }
}

export {
  getConfig,
  execEnroll,
  createConnection,
  closeConnection,
  createNetwork,
  listAllNetworks,
  readNetwork,
  deleteNetwork,
  createData,
  listAllData,
  readData,
  deleteData,
  listDataHistory
}
