# Fabric Node.js Container Image
# Used for the CA client application, the chaincode builder, and the chaincode peers
# This Dockerfile is based on: https://github.com/hyperledger/fabric-chaincode-node/tree/v2.4.1/docker/fabric-nodeenv
# The default image from Docker Hub uses Node version 12: https://hub.docker.com/layers/hyperledger/fabric-nodeenv/2.4/images/sha256-53ec564ee28ed1fcee3be9ed1459bcc98a22fc0d81e5a707239425615641786a?context=explore

# Default image
ARG NODE_VERSION="16.4.0"
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
