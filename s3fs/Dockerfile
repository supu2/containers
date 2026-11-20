###############################################################################
# The FUSE driver needs elevated privileges, run Docker with --privileged=true
###############################################################################

FROM alpine:3.24

RUN apk add --no-cache fuse-common s3fs-fuse
RUN sed -i s/"#user_allow_other"/"user_allow_other"/g /etc/fuse.conf

COPY docker-entrypoint.sh /
RUN ["chmod", "+x", "/docker-entrypoint.sh"]
CMD /docker-entrypoint.sh
