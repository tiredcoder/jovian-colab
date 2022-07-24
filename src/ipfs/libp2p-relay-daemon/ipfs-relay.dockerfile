# IPFS libp2p-relay-daemon container image with private network support
# Based on: https://github.com/ipfs/kubo/blob/v0.12.2/Dockerfile
ARG GO_VERSION="1.17"
ARG COMMIT="a32147234644cfef5b42a9f5ccaf99b6e6021fd4"
ARG TINI_VERSION="v0.19.0"

# Build
FROM "golang:$GO_VERSION-alpine" AS build
ARG COMMIT

WORKDIR /go/src
COPY pnet.patch ./

RUN apk add --no-cache git \
  && mkdir go-libp2p-relay-daemon \
  && cd go-libp2p-relay-daemon \
  && git config --global init.defaultBranch master \
  && git config --global advice.detachedHead false \
  && git init \
  && git remote add origin https://github.com/libp2p/go-libp2p-relay-daemon.git \
  && git fetch --depth 1 origin "$COMMIT" \
  && git checkout FETCH_HEAD \
  && git apply < ../pnet.patch \
  && go build -o /libp2p-relay-daemon ./cmd/libp2p-relay-daemon

# Deploy
FROM alpine
ARG TINI_VERSION

COPY --from=build /libp2p-relay-daemon /usr/local/bin/libp2p-relay-daemon
COPY start_relay.sh /usr/local/bin/start_relay
COPY config.default.json /usr/local/etc/libp2p-relay-daemon/config.json

ADD "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-muslc-amd64" /sbin/tini

RUN chmod 0755 /usr/local/bin/libp2p-relay-daemon /usr/local/bin/start_relay /sbin/tini \
 && adduser -D -h /usr/local/etc/libp2p-relay-daemon -u 1000 -G users ipfs \
 && chown -R ipfs:users /usr/local/etc/libp2p-relay-daemon \
 && apk add --no-cache jq

EXPOSE 4002/tcp
EXPOSE 4002/udp

# Set default user to ipfs instead of root (this user will be used if no user has been provided at container creation)
USER ipfs

# Important: this happens after the USER directive *when creating the container*, so permissions are correct
# I.e. this allows the Docker user to rw bind mount the '/usr/local/etc/libp2p-relay-daemon' directory
VOLUME /usr/local/etc/libp2p-relay-daemon

WORKDIR /usr/local/etc/libp2p-relay-daemon
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/start_relay"]
CMD ["--id=/usr/local/etc/libp2p-relay-daemon/identity", "--config=/usr/local/etc/libp2p-relay-daemon/config.json"]
