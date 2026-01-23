#!/bin/bash
set -e

IMAGE="$1"

echo "Pulling image from Docker Hub..."
echo "   Image: ${IMAGE}"
docker pull "${IMAGE}" || { echo "Failed to pull image"; exit 1; }
echo "Image pulled successfully"

echo "Validating image: $IMAGE"

# Metadata
docker inspect "$IMAGE" > image-info.json
docker image ls "$IMAGE" --format '{{.Size}}' > image-size.txt

# DYNAMIC cleanup + test
echo "Testing on dynamic port..."
FREE_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
echo "Dynamic port: $FREE_PORT"

# FORCE remove stale container (idempotent)
docker rm -f smoke-test 2>/dev/null || true

docker run -d --name smoke-test -p "$FREE_PORT:80" "$IMAGE"
sleep 5  # Startup buffer

# Health checks
curl -f "http://localhost:$FREE_PORT/" > smoke-test.html || { docker logs smoke-test; exit 1; }
curl -f "http://localhost:$FREE_PORT/" -I >> smoke-test.html

# Cleanup
docker stop smoke-test
docker rm smoke-test

echo "Smoke test PASSED"