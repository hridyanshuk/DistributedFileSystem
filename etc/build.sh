#!/usr/bin/env bash
# Sets up a persistent Rust build container.
#
#  - If the versioned image doesn't exist, it is built from ./Dockerfile.
#  - If the container doesn't exist, it is created (detached, stays running).
#  - If the container exists but is stopped, it is started.
#  - If the container exists but was made from an older image, it is recreated.
#
# Then use it manually:
#   docker exec -it build bash
#   docker exec -it build cargo build --release
#
# Bump IMAGE_VERSION whenever you change the Dockerfile.
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-my-rust-builder}"
IMAGE_VERSION="${IMAGE_VERSION:-1.0.1}"
IMAGE="${IMAGE_NAME}:${IMAGE_VERSION}"
CONTAINER_NAME="${CONTAINER_NAME:-build}"
CARGO_VOLUME="${CARGO_VOLUME:-${IMAGE_NAME}-cargo-cache}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Image: build only if this version doesn't exist
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo ">> Image $IMAGE found"
else
    echo ">> Image $IMAGE not found, building..."
    docker build -t "$IMAGE" -f Dockerfile .
fi

# 2. Container
create_container() {
    echo ">> Creating container '$CONTAINER_NAME' from $IMAGE"
    # Linux only: share host user/group names so the shell prompt shows your
    # real username instead of "I have no name!"
    local_user_mounts=()
    if [[ "$(uname -s)" == "Linux" ]]; then
        local_user_mounts=(-v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro)
    fi

    # -dit + bash as the main process makes `docker attach` give you a shell
    docker run -dit \
        --name "$CONTAINER_NAME" \
        --user "$(id -u):$(id -g)" \
        ${local_user_mounts[@]+"${local_user_mounts[@]}"} \
        -v "$SCRIPT_DIR":/workspace \
        -v "$CARGO_VOLUME":/cargo-cache \
        -e CARGO_HOME=/cargo-cache \
        -e HOME=/tmp \
        -w /workspace \
        "$IMAGE" \
        bash >/dev/null
}

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    want_id="$(docker image inspect -f '{{.Id}}' "$IMAGE")"
    have_id="$(docker container inspect -f '{{.Image}}' "$CONTAINER_NAME")"

    if [[ "$want_id" != "$have_id" ]]; then
        echo ">> Container '$CONTAINER_NAME' uses an older image, recreating"
        docker rm -f "$CONTAINER_NAME" >/dev/null
        create_container
    elif [[ "$(docker container inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" == "true" ]]; then
        echo ">> Container '$CONTAINER_NAME' already running"
    else
        echo ">> Starting existing container '$CONTAINER_NAME'"
        docker start "$CONTAINER_NAME" >/dev/null
    fi
else
    create_container
fi

echo ">> Ready. Use: docker exec -it $CONTAINER_NAME bash"



