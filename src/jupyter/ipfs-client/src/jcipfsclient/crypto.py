# Uses the PyCryptodome library (a fork of PyCrypto)
# Algorithms (symmetric encryption): ChaCha20, Salsa20, AES_256_CTR
#
# WARNING:
# The encryption has been adapted to work within the context of this project (i.e. together with IPFS)!
# ! DO NOT USE OUTSIDE OF THIS CODEBASE !
# 
# Notes:
#  - We are chunking the files as to reduce memory usage.
#  - AES_256_CTR: 256 bit because of long-term storage; CTR because of parallelization.
#  - ChaCha20 & Salsa20: We are incrementing the nonce for each chunk (i.e. a counter) as to prevent the preservation of patterns in the ciphertext
#    (i.e. the same plaintext chunk does not encrypt to the same ciphertext chunk because of using a different nonce).
#  - However, *entire* files (i.e. the same plaintext) encrypted with the *same key and nonce* will result in the same ciphertext (i.e. deterministic encryption).
#    This is a desired result as to apply deduplication inside of IPFS, but has privacy implications (changes between file revisions can be observed).
#  - We are not using a MAC (AEAD) because we're relying on IPFS (which uses immutable file blocks).
#  - To do / Future work: All three ciphers allow for parallelization (i.e. multi-threaded encryption/decryption).
#
# Docs: https://pycryptodome.readthedocs.io/en/v3.14.1/
import base64
from Crypto.Cipher import ChaCha20, Salsa20, AES
from Crypto.Random import get_random_bytes


# Generate key for specified cipher
def genKey(cipherMode='ChaCha20'):
  if cipherMode == 'ChaCha20': key = get_random_bytes(32) # random 256 bit key
  if cipherMode == 'Salsa20': key = get_random_bytes(32) # random 256 bit key
  if cipherMode == 'AES_256_CTR': key = get_random_bytes(32) # random 256 bit key
  return base64.b64encode(key).decode("ascii")


# Increment a string of bytes by 1
def incrementBytes(strBytes, strSize):
  strInt = int.from_bytes(strBytes, byteorder='big', signed=False)
  strInt += 1
  return strInt.to_bytes(strSize, byteorder='big', signed=False)


# Encrypt open file object using specified cipher
def encrypt(infileObj, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    key_ascii_bytes = base64Key.encode("ascii")
    key_bytes = base64.b64decode(key_ascii_bytes)

    if cipherMode == 'ChaCha20':
      # Fixed 64 bit nonce (used as counter; every file uses a unique key)
      nonce_bytes = b'\x00' * 8
      while chunk := infileObj.read(chunkSize):
        cipher = ChaCha20.new(key = key_bytes, nonce = nonce_bytes)
        encryptedChunk = cipher.encrypt(chunk)
        assert len(encryptedChunk) == len(chunk)
        nonce_bytes = incrementBytes(nonce_bytes, 8)
        yield encryptedChunk
    
    if cipherMode == 'Salsa20':
      # Fixed 64 bit nonce (used as counter; every file uses a unique key)
      nonce_bytes = b'\x00' * 8
      while chunk := infileObj.read(chunkSize):
        cipher = Salsa20.new(key = key_bytes, nonce = nonce_bytes)
        encryptedChunk = cipher.encrypt(chunk)
        assert len(encryptedChunk) == len(chunk)
        nonce_bytes = incrementBytes(nonce_bytes, 8)
        yield encryptedChunk

    if cipherMode == 'AES_256_CTR':
      # Fixed 0 bit nonce (nonce is used as an IV only; seperate 128 bit counter; every file uses a unique key)
      ivSpec = b'\x00' * 16
      cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, initial_value = ivSpec, nonce = b'')
      while chunk := infileObj.read(chunkSize):
        encryptedChunk = cipher.encrypt(chunk)
        assert len(encryptedChunk) == len(chunk)
        yield encryptedChunk
  except Exception as e:
    raise Exception("Error while encrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))


# Decrypt data from given HTTP response object using specified cipher
def decrypt(responseObj, outfile, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    with open(outfile, 'wb') as fileout:
      key_ascii_bytes = base64Key.encode("ascii")
      key_bytes = base64.b64decode(key_ascii_bytes)

      if cipherMode == 'ChaCha20':
        nonce_bytes = b'\x00' * 8 # Fixed nonce; see encrypt notes
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          cipher = ChaCha20.new(key = key_bytes, nonce = nonce_bytes)
          plaintextChunk = cipher.decrypt(chunk)
          assert len(plaintextChunk) == len(chunk)
          nonce_bytes = incrementBytes(nonce_bytes, 8)
          fileout.write(plaintextChunk)

      if cipherMode == 'Salsa20':
        nonce_bytes = b'\x00' * 8 # Fixed nonce; see encrypt notes
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          cipher = Salsa20.new(key = key_bytes, nonce = nonce_bytes)
          plaintextChunk = cipher.decrypt(chunk)
          assert len(plaintextChunk) == len(chunk)
          nonce_bytes = incrementBytes(nonce_bytes, 8)
          fileout.write(plaintextChunk)

      if cipherMode == 'AES_256_CTR':
        ivSpec = b'\x00' * 16 # Counter only; see encrypt notes
        cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, initial_value = ivSpec, nonce = b'')
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          plaintextChunk = cipher.decrypt(chunk)
          assert len(plaintextChunk) == len(chunk)
          fileout.write(plaintextChunk)
  except Exception as e:
    raise Exception("Error while decrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))
