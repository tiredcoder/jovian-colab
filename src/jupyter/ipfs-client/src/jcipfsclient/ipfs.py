# Functions to local IPFS peer and remote IPFS Cluster Pinning Service
#
# Docs:
#  go-ipfs peer RPC API (v0.12.2): https://github.com/ipfs/ipfs-docs/blob/b7c09c34e0737c79ad172a854dc3d8c98b50da65/docs/reference/http/api.md
#  IPFS Pinning Service API (1.0.0): https://ipfs.github.io/pinning-services-api-spec
from . import crypto
import sys
import os
import stat
import requests
import json
import socket
from urllib.parse import urlparse

def IpfsHttpRpcRequestHandler(url, json=True):
  try:
    response = requests.post(url)
    response.raise_for_status()
    if json:
      return response.json()
    else:
      return response
  except Exception as e:
    code = e.response.status_code
    if code == 500:
      raise Exception("RPC endpoint returned an error: '{error}'".format(error = str(e)))
    elif code == 400:
      raise Exception("Malformed RPC (possible argument type error): '{error}'".format(error = str(e)))
    elif code == 403:
      raise Exception("RPC call forbidden: '{error}'".format(error = str(e)))
    elif code == 404:
      raise Exception("RPC endpoint doesn't exist:'{error}'".format(error = str(e)))
    elif code == 405:
      raise Exception("HTTP Method Not Allowed: '{error}'".format(error = str(e)))


def getId(nodeApiUrl):
  try:
    data = IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/id')
    return data['ID']
  except Exception as e:
    print("Error while getting peer ID: " + str(e), file=sys.stderr)


def getStorageCacheUsage(nodeApiUrl):
  try:
    data = IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/repo/stat?size-only')
    return data['RepoSize']
  except Exception as e:
    print("Error while getting peer storage cache usage: " + str(e), file=sys.stderr)


def collectGarbage(nodeApiUrl):
  try:
    IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/repo/gc', False)
  except Exception as e:
    print("Error while collecting garbage: " + str(e), file=sys.stderr)


def joinNetwork(nodeApiUrl, nodeRepoPath, swarmKey, bootstrapNodes):
  try:
    # Change swarm key
    # IPFS lacks an API to change the key, so we have to interact with the filesystem directly
    os.chmod('{path}/swarm.key'.format(path = nodeRepoPath), stat.S_IRUSR | stat.S_IWUSR) #rw access
    with open('{path}/swarm.key'.format(path = nodeRepoPath), 'w') as keyFile:
      keyFile.write(swarmKey)
    os.chmod('{path}/swarm.key'.format(path = nodeRepoPath), stat.S_IRUSR) #ro access
    
    # Configure boostrap nodes
    IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/bootstrap/rm/all')
    for bootstrapNode in bootstrapNodes:
      IpfsHttpRpcRequestHandler(nodeApiUrl + "/api/v0/bootstrap/add?arg={node}".format(node = bootstrapNode))
    
    # Restart the node to load the swarm key and join the private IPFS network
    # The actual restarting is done out of bounds (i.e. via Docker, Podman, a service manager like systemd, etc.)
    IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/shutdown', False)
  except Exception as e:
    print("Error while joining IPFS network: " + str(e), file=sys.stderr)


def getPeers(nodeApiUrl):
  try:
    data = IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/swarm/peers')
    peers = []
    for peer in data['Peers']:
      peers.append(
        {
          'peer': peer['Peer'],
          'addr': peer['Addr']
        }
      )
    return peers
  except Exception as e:
    print("Error while getting peers: " + str(e), file=sys.stderr)


# Use the experimental Pinning Service API to pin the (encrypted) file on the cluster (this will trigger the cluster to download the file via IPFS)
def addRemotePin(pinServiceUrl, cid, user, password, pinServiceTLSCertFile, origins='None'):
  try:
    if origins == 'None':
      req = { "cid": cid }
    else:
      req = { "cid": cid, "origins": origins }
    response = requests.post(
      url = pinServiceUrl + '/pins',
      auth = (user, password),
      verify = pinServiceTLSCertFile,
      json = req
    )
    response.raise_for_status()
    return response.json()['requestid'] # Request ID of the pin request (this is the CID)
  except Exception as e:
    code = e.response.status_code
    if code == 401:
      print("Error while adding remote pin: Unauthorized: " + str(e), file=sys.stderr)
    else:
      print("Error while adding remote pin: " + str(e), file=sys.stderr)


# Use the experimental Pinning Service API to get the pin status (quied/pinned) on the cluster
def getRemotePinStatus(pinServiceUrl, requestId, user, password, pinServiceTLSCertFile):
  try:
    response = requests.get(
      url = pinServiceUrl + '/pins/{requestId}'.format(requestId = requestId),
      auth = (user, password),
      verify = pinServiceTLSCertFile
    )
    response.raise_for_status()
    return response.json()['status'] # Status of the pin request
  except Exception as e:
    code = e.response.status_code
    if code == 401:
      print("Error while getting status of remote pin: Unauthorized: " + str(e), file=sys.stderr)
    elif code == 404:
      print("Error while getting status of remote pin: Pin doesn't exist: " + str(e), file=sys.stderr)
    else:
      print("Error while getting status of remote pin: " + str(e), file=sys.stderr)


# Encrypt and add file to local node (from this Python client to the go-ipfs node via HTTP over raw TCP session)
# Added (encrypted) files are auto. pinned to local node
# Parse in chunks as to reduce memory usage
def addFile(nodeApiUrl, file, base64Key=None, chunkSize=1024*1024*10, cipherMode='ChaCha20'):
  try:
    url = urlparse(nodeApiUrl + '/api/v0/add?quieter')
    if url.scheme != 'http': raise Exception("URL scheme not set to HTTP.")
    if not os.path.exists(file): raise Exception("File '{file}' doesn't exist.".format(file = file))
    with open(file, 'rb') as filein:
      # Construct HTTP POST using multipart/form-data (RFC 1341, 1521, 1867, 2046)
      boundary = 'BOUN2e1920a7-9b35-4d7a-ab20-2f96f9611826' + 'BOUN' # Max. 70 chars (we concatenate these strings because we can't set the boundary directly if we also want to upload *this* file ;) )
      bodyStart = '--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="file"\r\n\r\n'.format(boundary = boundary)
      bodyEnd = '\r\n--{boundary}--\r\n'.format(boundary = boundary)
      contentLength = len(bodyStart) + os.stat(file).st_size + len(bodyEnd)
      httpHeader = 'POST /api/v0/add?quieter HTTP/1.1\r\nHost: {host}:{port}\r\nUser-Agent: JupyterLab IPFS Client\r\nAccept-Encoding: identity\r\nAccept: */*\r\nConnection: Keep-Alive\r\nContent-Length: {length}\r\nContent-Type: multipart/form-data; boundary={boundary}\r\n\r\n'.format(host = url.hostname, port = url.port, length = contentLength, boundary = boundary)

      # Open raw TCP socket
      with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.connect((url.hostname, url.port))

        # Send header and start of body
        dataBytes = httpHeader.encode('ascii')
        sock.send(dataBytes)
        dataBytes = bodyStart.encode('ascii')
        sock.send(dataBytes)

        # Send encrypted chunks
        if base64Key is None: base64Key = crypto.genKey(cipherMode)
        for chunk in crypto.encrypt(filein, base64Key, chunkSize, cipherMode):
          sock.send(chunk)
        
        # Send end of body
        dataBytes = bodyEnd.encode('ascii')
        sock.send(dataBytes)

        # Receive server response
        response = sock.recv(2048) # 2 KiB buffer, good response should be around 500 bytes
        response_ascii = response.decode("ascii")

        # Parse server (IPFS node) response: header
        statusCode = response_ascii.split()[1]
        if int(statusCode) != 200: raise Exception("HTTP status code error: {code}".format(code = statusCode))
      
        # Parse server (IPFS node) response: body
        bodyStartPos = response_ascii.find("\r\n\r\n")
        body = response_ascii[bodyStartPos+4:]
        size_hex_as_ascii = body.split('\r\n')[0] # Chunked Transfer Coding (RFC 7230)
        responseChunkSize = int(size_hex_as_ascii, 16)

        response_json_ascii = body.split('\r\n')[1].split('\n')[0] # Get first JSON object in response as ASCII text (remove newline)
        if (len(response_json_ascii) + 1) != responseChunkSize: raise Exception("Can't parse response's body: Chunked HTTP transfer incomplete.")
        response_json = json.loads(response_json_ascii)

        cid = response_json['Hash']
        return {'cid': cid, 'base64Key': base64Key, 'chunkSize': chunkSize, 'cipherMode': cipherMode}
  except Exception as e:
    print("Error while adding file: " + str(e), file=sys.stderr)


# Download (encrypted) file from IPFS and optionally pin to local node (otherwise the file will be garbage collected)
# Parse in chunks as to reduce memory usage
# We cache all downloaded (encrypted) files so other people can access them; we can pin them if we want to guarantee encrypted file availability
# Note that the '/api/v0/get' endpoint will *not* give the content but the entire IPFS object (IPFS metadata + content). This behavior differs from the CLI get command (hence why we use the cat API endpoint).
def getFile(nodeApiUrl, cid, outfile, base64Key, chunkSize=1024*1024*10, cipherMode='ChaCha20', pin=False):
  try:
    with requests.post(nodeApiUrl + '/api/v0/cat?arg={cid}'.format(cid = cid), stream=True) as response:
      response.raise_for_status()
      crypto.decrypt(response, outfile, base64Key, chunkSize, cipherMode)
    if pin: IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/pin/add?arg={cid}'.format(cid = cid))
  except Exception as e:
    print("Error while getting file: " + str(e), file=sys.stderr)


# Remove pin from local node
def rmPin(nodeApiUrl, cid):
  try:
    IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/pin/rm?arg={cid}'.format(cid = cid))
  except Exception as e:
    print("Error while removing pin: " + str(e), file=sys.stderr)


# Get pinned CIDs on local node
def getPins(nodeApiUrl):
  try:
    data = IpfsHttpRpcRequestHandler(nodeApiUrl + '/api/v0/pin/ls?type=recursive')
    pins = []
    for pin in data['Keys']:
      pins.append(pin)
    return pins
  except Exception as e:
    print("Error while getting pins: " + str(e), file=sys.stderr)
