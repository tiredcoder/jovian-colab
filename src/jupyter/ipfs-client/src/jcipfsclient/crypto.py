# Uses the PyCryptodome library (a fork of PyCrypto)
# Stream ciphers (symmetric encryption): ChaCha20, Salsa20, AES_256_CTR
#
# WARNING:
# The encryption has been adapted to work within the context of this project (i.e. together with IPFS)!
# ! DO NOT USE OUTSIDE OF THIS CODEBASE !
# 
# Notes:
#  - We are chunking the files as to reduce memory usage.
#  - AES_256_CTR: 256 bit because of long-term storage; CTR because of parallelization.
#  - Entire files (i.e. the same plaintext) encrypted with the *same key and nonce* will result in the same ciphertext (i.e. deterministic encryption).
#    This is a desired result as to apply deduplication inside of IPFS, but has privacy implications (changes between file revisions can be observed).
#  - We are not using a MAC (AEAD) because we're relying on IPFS (which uses immutable file blocks).
#  - To do / Future work: All three ciphers allow for parallelization (i.e. multi-threaded encryption/decryption).
#
# Docs: https://pycryptodome.readthedocs.io/en/v3.15.0/
from base64 import b64decode, b64encode
from Crypto.Cipher import ChaCha20, Salsa20, AES
from Crypto.Random import get_random_bytes
from Crypto.Util import Counter


# Generate key for specified cipher
def genKey(cipherMode='ChaCha20'):
  if cipherMode == 'plain': key = b'\x00' # static 1 Byte key (all zeros; i.e. we don't use a key)
  if cipherMode == 'ChaCha20': key = get_random_bytes(32) # random 256 bit key
  if cipherMode == 'Salsa20': key = get_random_bytes(32) # random 256 bit key
  if cipherMode == 'AES_256_CTR': key = get_random_bytes(32) # random 256 bit key
  return b64encode(key).decode("ascii")


# Encrypt open file object using specified cipher and yields encrypted chucks
def encrypt(infileObj, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    if cipherMode == 'plain':
      while chunk := infileObj.read(chunkSize):
        yield chunk # No encryption
    else:
      key_ascii_bytes = base64Key.encode("ascii")
      key_bytes = b64decode(key_ascii_bytes)
      if cipherMode == 'ChaCha20': cipher = ChaCha20.new(key = key_bytes, nonce = b'\x00' * 8) # Fixed 64 bit nonce (every file uses a unique key)
      elif cipherMode == 'Salsa20': cipher = Salsa20.new(key = key_bytes, nonce = b'\x00' * 8) # Fixed 64 bit nonce (every file uses a unique key)
      elif cipherMode == 'AES_256_CTR': cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, counter = Counter.new(128)) # Fixed 0 bit nonce and 128 bit counter (every file uses a unique key)
      while chunk := infileObj.read(chunkSize):
        encryptedChunk = cipher.encrypt(chunk)
        assert len(encryptedChunk) == len(chunk)
        yield encryptedChunk
  except Exception as e:
    raise Exception("Error while encrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))


# Decrypt data from given HTTP response object using specified cipher and writes to file
def decrypt(responseObj, outfile, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    with open(outfile, 'wb') as fileout:
      if cipherMode == 'plain':
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          fileout.write(chunk) # No decryption
      else:
        key_ascii_bytes = base64Key.encode("ascii")
        key_bytes = b64decode(key_ascii_bytes)
        if cipherMode == 'ChaCha20': cipher = ChaCha20.new(key = key_bytes, nonce = b'\x00' * 8)
        elif cipherMode == 'Salsa20': cipher = Salsa20.new(key = key_bytes, nonce = b'\x00'* 8)
        elif cipherMode == 'AES_256_CTR': cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, counter = Counter.new(128))
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          plaintextChunk = cipher.decrypt(chunk)
          assert len(plaintextChunk) == len(chunk)
          fileout.write(plaintextChunk)
  except Exception as e:
    raise Exception("Error while decrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))


# Decrypt data from given file object using specified cipher and yields decrypted chucks
def decrypt_from_file(infileObj, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    if cipherMode == 'plain':
      while chunk := infileObj.read(chunkSize):
        yield chunk # No decryption
    else:
      key_ascii_bytes = base64Key.encode("ascii")
      key_bytes = b64decode(key_ascii_bytes)
      if cipherMode == 'ChaCha20': cipher = ChaCha20.new(key = key_bytes, nonce =  b'\x00' * 8)
      elif cipherMode == 'Salsa20': cipher = Salsa20.new(key = key_bytes, nonce =  b'\x00' * 8)
      elif cipherMode == 'AES_256_CTR': cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, counter = Counter.new(128))
      while chunk := infileObj.read(chunkSize):
        plaintextChunk = cipher.decrypt(chunk)
        assert len(plaintextChunk) == len(chunk)
        yield plaintextChunk
  except Exception as e:
    raise Exception("Error while decrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))
