#!/bin/bash

# Check if required environment variables are set
if [ -z "$TARGET_RANGE" ]; then
    echo "ERROR: TARGET_RANGE environment variable not set"
    exit 1
fi

if [ -z "$ELASTICSEARCH_HOST" ]; then
    echo "ERROR: ELASTICSEARCH_HOST environment variable not set"
    exit 1
fi

if [ -z "$ELASTICSEARCH_INDEX" ]; then
    echo "ERROR: ELASTICSEARCH_INDEX environment variable not set"
    exit 1
fi

if [ -z "$ELASTICSEARCH_USER" ] || [ -z "$ELASTICSEARCH_PASSWORD" ]; then
    echo "ERROR: Elasticsearch credentials not set"
    exit 1
fi

echo "Starting scan of ranges: $TARGET_RANGE"

# Run naabu scan with list file and capture output
naabu -host "$TARGET_RANGE" -json -silent $NAABU_EXTRA_ARGS | jq -c '. +{hostname: "'$HOSTNAME'", "@timestamp": .timestamp} | del(.timestamp) ' | awk '{print "{\"index\":{}}\n"$1}' > result.json

# Send to Elasticsearch using bulk API
response=$(curl -X POST "$ELASTICSEARCH_HOST/$ELASTICSEARCH_INDEX/_bulk" \
        -H "Content-Type: application/x-ndjson" \
        -u "$ELASTICSEARCH_USER:$ELASTICSEARCH_PASSWORD" \
        --data-binary "@result.json" \
        --compressed \
        -w "\n%{http_code}")

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo "Successfully sent bulk results to Elasticsearch"
else
    echo "Failed to send results to Elasticsearch. HTTP Code: $http_code"
    echo "Response: $(echo "$response" | head -n1)"
fi

echo "Scan and data transfer completed"