# syntax=docker/dockerfile:1

# ---- Builder ----
FROM rust:1.90-slim-bookworm AS builder

# Install build dependencies required by common crates (openssl/pkg-config).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pkg-config \
        libssl-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache dependencies first: copy manifests and build a stub to warm the cache.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src \
    && echo "fn main() {}" > src/main.rs \
    && cargo build --release \
    && rm -rf src

# Build the actual application.
COPY . .
# Ensure the real main.rs is newer than the cached stub so it gets recompiled.
RUN touch src/main.rs \
    && cargo build --release \
    && strip target/release/copilot-api-proxy

# ---- Runtime ----
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 appuser

WORKDIR /home/appuser

COPY --from=builder /app/target/release/copilot-api-proxy /usr/local/bin/copilot-api-proxy

USER appuser

EXPOSE 9876

ENTRYPOINT ["copilot-api-proxy"]
CMD ["server", "--port", "9876"]
