FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY verify-public-release-kit.sh /usr/local/bin/vihs-public-release-kit-smoke
RUN chmod +x /usr/local/bin/vihs-public-release-kit-smoke

ENTRYPOINT ["/usr/local/bin/vihs-public-release-kit-smoke"]
