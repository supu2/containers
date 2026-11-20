#!/bin/sh
set -euo pipefail
set -o errexit
set -o errtrace
IFS=$'\n\t'

export S3_ACL=${S3_ACL:-private}

mkdir -p ${MNT_POINT}

s3fs  ${S3_BUCKET} ${MNT_POINT} -d -f -o url=${S3_URL} -o ${MNT_OPTS}