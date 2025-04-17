# Use Alpine Linux as base image for smaller size
FROM golang:1.24.2-alpine AS build-env
ARG NAABU_VERSION=v2.3.4
RUN apk add --no-cache build-base libpcap-dev git
WORKDIR /app
RUN git clone --depth 1  --branch $NAABU_VERSION https://github.com/projectdiscovery/naabu.git .
RUN go mod download
RUN go build ./cmd/naabu

# Release
FROM alpine:3.21
RUN apk upgrade --no-cache \
    && apk add --no-cache nmap libpcap-dev bind-tools ca-certificates nmap-scripts curl jq bash
COPY --from=build-env /app/naabu /usr/local/bin/
COPY scan.sh /app/
WORKDIR /app
RUN chmod +x /app/scan.sh

# Set environment variables
ENV ELASTICSEARCH_HOST=http://elasticsearch:9200
ENV ELASTICSEARCH_INDEX=network_scans
ENV ELASTICSEARCH_USER=""
ENV ELASTICSEARCH_PASSWORD=""
ENV TARGET_RANGE=""
ENV NAABU_EXTRA_ARGS=""

# Run the scanning script
CMD ["/app/scan.sh"]