FROM alpine as builder
RUN apk add --no-cache curl jq; \
    export VERSION=$(curl -s  https://api.github.com/repos/P3TERX/GeoLite.mmdb/releases/latest | jq -r '.tag_name'); \
    curl -s -L -o /GeoLite2-City.mmdb https://github.com/P3TERX/GeoLite.mmdb/releases/download/$VERSION/GeoLite2-City.mmdb
FROM alpine
COPY --from=builder /GeoLite2-City.mmdb /GeoLite2-City.mmdb