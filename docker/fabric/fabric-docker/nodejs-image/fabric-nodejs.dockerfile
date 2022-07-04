# Fabric Node.js Container Image
# Used by the CA client application, the chaincode builder, and the chaincode peers
# This Dockerfile is based on: https://github.com/hyperledger/fabric-chaincode-node/blob/v2.4.2/docker/fabric-nodeenv

# Default image
ARG NODE_VERSION="16"
FROM "node:${NODE_VERSION}-alpine"

# Install dependencies and set up chaincode config
RUN apk add --no-cache \
	make \
	python3 \
	g++;
RUN mkdir -p /chaincode/input \
	&& mkdir -p /chaincode/output \
	&& mkdir -p /usr/local/src;
RUN npm install -g npm@latest
ADD build.sh start.sh /chaincode/
RUN chmod 0755 /chaincode/build.sh /chaincode/start.sh
