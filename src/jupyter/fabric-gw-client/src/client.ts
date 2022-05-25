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
import { connect, Identity, Signer, signers } from '@hyperledger/fabric-gateway';
import { TextDecoder } from 'util';

interface config {
  organization: string;
  mspId: string;
  identity: string;
  idCertFile: string,
  idKeyFile: string,
  caEndpoint: string;
  caTlsCertFile: string;
  caName: string;
  gatewayEndpoint: string;
  gatewayTlsCertFile: string;
  gatewayHostAlias: string;
}

function EnvOrConfigOrError(envVariableName: string, configFileValue: string): string {
  const envVariableValue: string|undefined = process.env[envVariableName];
  if (typeof envVariableValue !== 'undefined') return envVariableValue;
  if (typeof configFileValue !== 'undefined') return configFileValue;
  throw new Error('Missing configuration'); 
}

const parseConfig = async (configFile?: string, organization?: string): Promise<config> => {
  console.log(`Configuration File: ${configFile}`);
  try {
    // Load config file
    const content = configFile ? await YAML.parse(await fsp.readFile(path.resolve(configFile),'utf8')) : undefined;
    if (typeof content == 'undefined') console.log('Warning: No config file provided! Trying to use environment only.');

    // Set organization (env > CLI arg > config file)
    const org: string|undefined = process.env['FABRIC_ORG'] || organization || (content ? content.defaultOrg : undefined);
    if (typeof org == 'undefined') throw new Error('Organization is not specified');

    // Set config (env > config file )
    const config: config = {
      organization: org,
      mspId: EnvOrConfigOrError('FABRIC_MSPID', content ? content.organizations[org].mspid : undefined),
      identity: EnvOrConfigOrError('FABRIC_ID', content ? content.organizations[org].identity : undefined ),
      idCertFile: EnvOrConfigOrError('FABRIC_ID_CERT', content ? content.identities[content.organizations[org].identity].cert.path : undefined ),
      idKeyFile: EnvOrConfigOrError('FABRIC_ID_KEY', content ? content.identities[content.organizations[org].identity].key.path : undefined ),
      caEndpoint: EnvOrConfigOrError('FABRIC_CA', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].url : undefined),
      caTlsCertFile: EnvOrConfigOrError('FABRIC_CA_CERT', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].tlsCACerts.path : undefined),
      caName: EnvOrConfigOrError('FABRIC_CA_NAME', content ? content.certificateAuthorities[content.organizations[org].certificateAuthority].caName : undefined),
      gatewayEndpoint: EnvOrConfigOrError('FABRIC_GATEWAY', content ? content.gateways[content.organizations[org].gateway].url : undefined),
      gatewayTlsCertFile: EnvOrConfigOrError('FABRIC_GATEWAY_CERT', content ? content.gateways[content.organizations[org].gateway].tlsCACerts.path : undefined),
      gatewayHostAlias: EnvOrConfigOrError('FABRIC_GATEWAY_HOST_ALIAS', content ? content.gateways[content.organizations[org].gateway].grpcOptions['ssl-target-name-override'] : undefined)
    }
    return config;
  } catch(error) {
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

const enroll = async (identity: string, idCertFile: string, idKeyFile: string, secret: string, caEndpoint: string, caTlsCertFiles: string[], caName: string): Promise<void> => {
  try {
    // Don't enroll if credentials already exist
    if (await fileExists(idCertFile)) throw new Error(`file '${idCertFile}' exists`);
    if (await fileExists(idKeyFile)) throw new Error(`file '${idKeyFile}' exists`);
    
    // Set full paths for all CA TLS certs
    caTlsCertFiles.forEach((certFile: string, i: number) => {
      caTlsCertFiles[i] = path.resolve(certFile);
    });
    
    // Enroll the user
    const ca = new FabricCAServices(caEndpoint, { trustedRoots: caTlsCertFiles, verify: false }, caName);
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

const gatewayExec = async (client: grpc.Client, identity: Identity, signer: Signer, channel: string, chaincode: string): Promise<void> => {
  // Connect to the gateway
  const gateway = connect({identity, signer, client});

  // Interact with the chaincode
  try {
    const network = gateway.getNetwork(channel);
    const contract = network.getContract(chaincode);
    const utf8Decoder = new TextDecoder();

    // Put
    //const putResult = await contract.submitTransaction('addNetwork', 'net1', 'dns1;dns2', 'key', 'acl');
    //console.log('Put result:', utf8Decoder.decode(putResult));
    
    // Get
    const getResult = await contract.evaluateTransaction('getNetwork', 'net1');
    console.log('Get result:', utf8Decoder.decode(getResult));
  } catch (error) {
    console.error(`Fabric Gateway error : ${error}`);
  } finally {
    gateway.close();
  }
}

async function getConfig(configFile: string, organization: string): Promise<config> {
  // Parse config (from environment vars or file)
  const config: config = configFile ?
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

async function execEnroll(config: config, secret: string): Promise<void> {
  console.log(' Enrolling... ');
  await enroll(config.identity, config.idCertFile, config.idKeyFile, secret, config.caEndpoint, [config.caTlsCertFile], config.caName);
  console.log('Enrollment complete!');
}

async function execTransaction(config: config): Promise<void> {
  console.log(' Gateway exec... ');

  // Identity
  const identity: Identity = await createGatewayIdentity(config.mspId, config.idCertFile);
  const signer: Signer = await createGatewaySigner(config.idKeyFile);

  // Create gRPC connection
  const gRpcClient: grpc.Client = await newGrpcConnection(config.gatewayEndpoint, config.gatewayTlsCertFile, config.gatewayHostAlias);

  // Exec chaincode
  await gatewayExec(gRpcClient, identity, signer, 'consortium-chain', 'consortium-cc-ipfs');
  
  gRpcClient.close();
}

// DO: add all functions (get IPFS network, etc.) here for chaincode!

export {
  getConfig,
  execEnroll,
  execTransaction
}
