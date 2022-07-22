# IPFS libp2p-relay-daemon Container Image With Private Network Support

ARG GO_VERSION="1.17-alpine"

# Build
FROM "golang:$GO_VERSION" AS build

WORKDIR /go/src
COPY pnet.patch ./

ENV COMMIT="a32147234644cfef5b42a9f5ccaf99b6e6021fd4"
RUN apk add --no-cache git \
  && mkdir go-libp2p-relay-daemon \
  && cd go-libp2p-relay-daemon \
  && git init \
  && git remote add origin https://github.com/libp2p/go-libp2p-relay-daemon.git \
  && git fetch --depth 1 origin "${COMMIT}" \
  && git checkout FETCH_HEAD \
  && git apply < ../pnet.patch \
  && go build -o /libp2p-relay-daemon ./cmd/libp2p-relay-daemon

# Deploy
FROM alpine

COPY --from=build /libp2p-relay-daemon /usr/local/bin/libp2p-relay-daemon
COPY start_relay.sh /usr/local/bin/start_relay
COPY config.json /usr/local/etc/libp2p-relay-daemon/config.json

ENV TINI_VERSION="v0.19.0"
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-muslc-amd64 /sbin/tini

RUN chmod 0755 /usr/local/bin/libp2p-relay-daemon /usr/local/bin/start_relay /sbin/tini \
 && adduser -D -h /usr/local/etc/libp2p-relay-daemon -u 1000 -G users ipfs \
 && chown -R ipfs:users /usr/local/etc/libp2p-relay-daemon \
 && apk add --no-cache jq

USER ipfs
EXPOSE 4002/tcp
EXPOSE 4002/udp
WORKDIR /usr/local/etc/libp2p-relay-daemon

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/start_relay"]
CMD ["--id=/usr/local/etc/libp2p-relay-daemon/identity", "--config=/usr/local/etc/libp2p-relay-daemon/config.json"]
