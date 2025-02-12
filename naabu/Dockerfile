# Use Alpine Linux as base image for smaller size
ARG version=v0.0.1
FROM projectdiscovery/naabu:v2.3.3

# Install required packages
RUN apk add --no-cache \
    curl \
    jq \
    bash

# Copy scanning script
COPY scan.sh /app/
WORKDIR /app
RUN chmod +x /app/scan.sh

# Set environment variables
ENV ELASTICSEARCH_HOST=http://elasticsearch:9200
ENV ELASTICSEARCH_INDEX=network_scans
ENV ELASTICSEARCH_USER=""
ENV ELASTICSEARCH_PASSWORD=""
ENV TARGET_RANGE=""

# Run the scanning script
ENTRYPOINT ["/app/scan.sh"]