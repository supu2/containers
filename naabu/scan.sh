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

# Create a temporary file for target list
TEMP_TARGET_FILE=$(mktemp)

# Convert comma-separated CIDR ranges to line-separated format
echo "$TARGET_RANGE" | tr ',' '\n' > "$TEMP_TARGET_FILE"

echo "Starting scan of ranges: $TARGET_RANGE"

# Run naabu scan with list file and capture output
scan_output=$(naabu -l "$TEMP_TARGET_FILE" -json -rate 100 -silent | jq -c '. +{hostname: "'$HOSTNAME'"}' | awk '{print "{\"index\":{}}\n"$1}')

# Send to Elasticsearch using bulk API
response=$(curl -X POST "$ELASTICSEARCH_HOST/$ELASTICSEARCH_INDEX/_bulk" \
        -H "Content-Type: application/x-ndjson" \
        -u "$ELASTICSEARCH_USER:$ELASTICSEARCH_PASSWORD" \
        --data-binary "$scan_output" \
        -w "\n%{http_code}")

http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo "Successfully sent bulk results to Elasticsearch"
else
    echo "Failed to send results to Elasticsearch. HTTP Code: $http_code"
    echo "Response: $(echo "$response" | head -n1)"
fi

echo "Scan and data transfer completed"