FROM ghcr.io/vdjagilev/nmap-formatter:v3.0.5 as nmap-formatter
# Release
FROM alpine:3.21
RUN apk upgrade --no-cache \
    && apk add --no-cache nmap  ca-certificates nmap-scripts curl jq bash
COPY --from=nmap-formatter /bin/nmap-formatter /bin/nmap-formatter
COPY scan.sh /app/
WORKDIR /app
RUN chmod +x /app/scan.sh

# Set environment variables
ENV ELASTICSEARCH_HOST=http://elasticsearch:9200
ENV ELASTICSEARCH_INDEX=network_scans
ENV ELASTICSEARCH_USER=""
ENV ELASTICSEARCH_PASSWORD=""
ENV TARGET_RANGE=""
ENV NMAP_EXTRA_ARGS=""

# Run the scanning script
CMD ["/app/scan.sh"]