FROM alpine as builder
RUN apk add curl && mkdir -p /binary  && cd /binary \
  && curl -L https://github.com/derailed/k9s/releases/download/v0.50.9/k9s_Linux_amd64.tar.gz | tar zxf - k9s  -O > k9s \
  && curl -L https://get.helm.sh/helm-v3.18.5-linux-amd64.tar.gz | tar zxf - linux-amd64/helm  -O > helm \
  && curl -L https://github.com/k0sproject/k0s/releases/download/v1.33.3%2Bk0s.0/k0s-v1.33.3+k0s.0-amd64 -o k0s \
  && curl -LO https://dl.k8s.io/release/v1.33.3/bin/linux/amd64/kubectl \
  && chmod +x *

FROM scratch
COPY --from=builder /binary /binary
