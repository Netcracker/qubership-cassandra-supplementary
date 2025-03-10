FROM --platform=$BUILDPLATFORM golang:1.23.0-alpine3.20 AS builder

ENV GOSUMDB=off GOPRIVATE=github.com/Netcracker

RUN apk add --no-cache git
RUN --mount=type=secret,id=GH_ACCESS_TOKEN \
    git config --global url."https://$(cat /run/secrets/GH_ACCESS_TOKEN)@github.com/".insteadOf "https://github.com/"

COPY . /workspace

WORKDIR /workspace
RUN go mod tidy

# Build
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o ./build/_output/bin/cassandra-services \
    -gcflags all=-trimpath=${GOPATH} -asmflags all=-trimpath=${GOPATH} ./main.go


FROM alpine:3.17.3

ENV OPERATOR=/usr/local/bin/cassandra-services \
    USER_UID=1001 \
    USER_NAME=cassandra-services

RUN echo 'https://dl-cdn.alpinelinux.org/alpine/v3.17/main/' > /etc/apk/repositories \
    && apk add --no-cache openssl curl

COPY bin/cassandra-services ${OPERATOR}
COPY build/bin /usr/local/bin
# COPY sf-class2-root.crt /usr

RUN chmod +x /usr/local/bin/entrypoint
RUN  chmod +x /usr/local/bin/user_setup && /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}
