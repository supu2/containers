docker build -t ghcr.io/supu2/containers/naabu naabu
docker run -it --rm \
    -e TARGET_RANGE="1.1.1.1" -e NAABU_EXTRA_ARGS="-p 53" -e HOSTNAME=test \
    -e ELASTICSEARCH_HOST=1.1.1.1 -e ELASTICSEARCH_INDEX=test \
    -e ELASTICSEARCH_USER=user -e ELASTICSEARCH_PASSWORD=password \
    ghcr.io/supu2/containers/naabu