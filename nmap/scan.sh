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

upload () {
    if [ -s "result.json" ]; then
        # Send to Elasticsearch using bulk API
        response=$(curl -X POST "$ELASTICSEARCH_HOST/$ELASTICSEARCH_INDEX/_bulk" \
                -H "Content-Type: application/x-ndjson" \
                -u "$ELASTICSEARCH_USER:$ELASTICSEARCH_PASSWORD" \
                --data-binary "@result.json" \
                --compressed \
                -s -w "\n%{http_code}")

        http_code=$(echo "$response" | tail -n1)
        if [ "$http_code" = "200" ]; then
            echo "Successfully sent bulk results to Elasticsearch for $TARGET"
        else
            echo "Failed to send results to Elasticsearch. HTTP Code: $http_code"
            echo "Response: $(echo "$response" | head -n1)"
        fi
    fi
}
read -ra ARGS_ARRAY <<< "$NMAP_EXTRA_ARGS"

IFS=,
for TARGET in $TARGET_RANGE;
do
    echo "Starting TCP scan of range: $TARGET"
    # Run naabu scan with list file and capture output
    nmap -sS $TARGET "${ARGS_ARRAY[@]}" -oX - | nmap-formatter json | jq -c '.Host[]' 2>/dev/null | awk '{print "{\"index\":{}}\n"$1}' | tee result.json | grep -v "index"
    upload
done
for TARGET in $TARGET_RANGE;
do
    echo "Starting UDP scan of range: $TARGET"
    # Run naabu scan with list file and capture output
    nmap -sU $TARGET "${ARGS_ARRAY[@]}" -oX - | nmap-formatter json | jq -c '.Host[]' 2>/dev/null | awk '{print "{\"index\":{}}\n"$1}' | tee result.json | grep -v "index"
    upload
done
echo "Scan and data transfer completed"