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
# Docs: https://pycryptodome.readthedocs.io/en/v3.15.0/
import base64
from Crypto.Cipher import ChaCha20, Salsa20, AES
from Crypto.Random import get_random_bytes
from io import BytesIO


# Generate key for specified cipher
def genKey(cipherMode='ChaCha20'):
  if cipherMode == 'plain': key = b'\x00' # static 1 Byte key (all zeros; i.e. we don't use a key)
  if cipherMode == 'ChaCha20': key = get_random_bytes(32) # random 256 bit key
  if cipherMode == 'Salsa20': key = get_random_bytes(32) # random 256 bit key
  if cipherMode == 'AES_256_CTR': key = get_random_bytes(32) # random 256 bit key
  return base64.b64encode(key).decode("ascii")


# Increment a string of bytes by 1
def incrementBytes(strBytes, strSize):
  strInt = int.from_bytes(strBytes, byteorder='big', signed=False)
  strInt += 1
  return strInt.to_bytes(strSize, byteorder='big', signed=False)


# Encrypt open file object using specified cipher and yields encrypted chucks
def encrypt(infileObj, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    key_ascii_bytes = base64Key.encode("ascii")
    key_bytes = base64.b64decode(key_ascii_bytes)

    if cipherMode == 'plain':
      # No encryption
      while chunk := infileObj.read(chunkSize):
        yield chunk

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


# Decrypt data from given HTTP response object using specified cipher and writes to file
def decrypt(responseObj, outfile, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    with open(outfile, 'wb') as fileout:
      key_ascii_bytes = base64Key.encode("ascii")
      key_bytes = base64.b64decode(key_ascii_bytes)

      if cipherMode == 'plain':
        # No decryption
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          fileout.write(chunk)
      
      if cipherMode == 'ChaCha20' or cipherMode == 'Salsa20':
        with BytesIO() as buffer:
          nonce_bytes = b'\x00' * 8 # Fixed nonce; see encrypt notes
          def decrypt_chacha_salsa():
            nonlocal nonce_bytes
            if cipherMode == 'ChaCha20': cipher = ChaCha20.new(key = key_bytes, nonce = nonce_bytes)
            if cipherMode == 'Salsa20': cipher = Salsa20.new(key = key_bytes, nonce = nonce_bytes)
            plaintextChunk = cipher.decrypt((buffer.getbuffer())[0:buffer.tell()]) # Get the size of the buffer's content, not the buffer size
            assert len(plaintextChunk) == len((buffer.getbuffer())[0:buffer.tell()])
            fileout.write(plaintextChunk)
            nonce_bytes = incrementBytes(nonce_bytes, 8)
          for chunk in responseObj.iter_content(chunk_size = chunkSize):
            # The nonce is linked to chunk size, but the HTTP response chunks might differ (e.g. nonce is incremented for a chunk size of 10MiB, but we get HTTP responses of 4KiB)
            # We use an in-memory buffer to match the chunk size (i.e. buffer the HTTP responses until we reach the desired chunk size)
            if buffer.tell() + len(chunk) > chunkSize:
              bufferFree = chunkSize - buffer.tell()
              buffer.write(chunk[0:bufferFree])
              decrypt_chacha_salsa()
              buffer.flush()
              buffer.seek(0)
              buffer.write(chunk[bufferFree:])
            else:
              buffer.write(chunk)
          decrypt_chacha_salsa()

      if cipherMode == 'AES_256_CTR':
        ivSpec = b'\x00' * 16 # Counter only; see encrypt notes
        cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, initial_value = ivSpec, nonce = b'')
        for chunk in responseObj.iter_content(chunk_size = chunkSize):
          plaintextChunk = cipher.decrypt(chunk)
          assert len(plaintextChunk) == len(chunk)
          fileout.write(plaintextChunk)
  except Exception as e:
    raise Exception("Error while decrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))


# Decrypt data from given file object using specified cipher and yields decrypted chucks
def decrypt_from_file(infileObj, base64Key, chunkSize, cipherMode='ChaCha20'):
  try:
    key_ascii_bytes = base64Key.encode("ascii")
    key_bytes = base64.b64decode(key_ascii_bytes)

    if cipherMode == 'plain':
      # No decryption
      while chunk := infileObj.read(chunkSize):
        yield chunk

    if cipherMode == 'ChaCha20' or cipherMode == 'Salsa20':
      nonce_bytes = b'\x00' * 8 # Fixed nonce; see encrypt notes
      while chunk := infileObj.read(chunkSize):
        if cipherMode == 'ChaCha20': cipher = ChaCha20.new(key = key_bytes, nonce = nonce_bytes)
        if cipherMode == 'Salsa20': cipher = Salsa20.new(key = key_bytes, nonce = nonce_bytes)
        plaintextChunk = cipher.decrypt(chunk)
        assert len(plaintextChunk) == len(chunk)
        nonce_bytes = incrementBytes(nonce_bytes, 8)
        yield plaintextChunk

    if cipherMode == 'AES_256_CTR':
      ivSpec = b'\x00' * 16 # Counter only; see encrypt notes
      cipher = AES.new(key = key_bytes, mode = AES.MODE_CTR, initial_value = ivSpec, nonce = b'')
      while chunk := infileObj.read(chunkSize):
        plaintextChunk = cipher.decrypt(chunk)
        assert len(plaintextChunk) == len(chunk)
        yield plaintextChunk
  except Exception as e:
    raise Exception("Error while decrypting using {cipherMode}: {error}'".format(cipherMode = cipherMode, error = str(e)))
