# Build environment image for the Rust project.
# Add any system libraries your crates need to the apt-get list below.
FROM rust:1-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        cmake \
        clang \
        lld \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Dev tooling
RUN rustup component add rustfmt clippy

# Optional: cross-compilation targets (uncomment as needed)
# RUN rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-gnu

# Cargo registry/git cache lives here so it can be a named volume
ENV CARGO_HOME=/cargo-cache
RUN mkdir -p /cargo-cache && chmod -R 777 /cargo-cache

WORKDIR /workspace
CMD ["cargo", "build", "--release"]
