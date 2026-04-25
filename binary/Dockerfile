FROM alpine as builder
ARG K9S_VERSION=v0.50.18
ARG K8S_VERSION=v1.35.3
ARG K0S_VERSION=$K8S_VERSION+k0s.0
ARG HELM_VERSION=v4.1.4
RUN apk add curl && mkdir -p /binary  && cd /binary \
  && curl -L https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz | tar zxf - k9s  -O > k9s \
  && curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar zxf - linux-amd64/helm  -O > helm \
  && curl -L https://github.com/k0sproject/k0s/releases/download/${K0S_VERSION}/k0s-${K0S_VERSION}-amd64 -o k0s \
  && curl -LO https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl \
  && chmod +x *

FROM scratch
COPY --from=builder /binary /
