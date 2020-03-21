FROM golang:1.13-alpine3.11

ARG HUGO_VERSION

ENV GO111MODULE=on

RUN apk add gcc musl-dev g++ make

RUN go get github.com/gohugoio/hugo@${HUGO_VERSION} \
	&& go install --tags extended github.com/gohugoio/hugo

ARG USER
ARG USERID
ARG GROUP
ARG GROUPID

RUN addgroup -g ${GROUPID} ${GROUP} || exit 0
RUN adduser -G ${GROUP} -u ${USERID} -D ${USER}

USER ${USER}

WORKDIR /nornir.tech
