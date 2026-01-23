#!/bin/bash
set -e

IMAGE="$1"  # arkb2023/abode-website:main-v1.0.xx

# Pull latest image
echo "Pulling image from Docker Hub..."
echo "   Image: ${IMAGE}"
docker pull ${IMAGE} || {
  echo "Failed to pull image"
  exit 1
}
echo "Image pulled successfully"
echo ""

echo "Validating image: $IMAGE"

# 1. Inspect & metadata
docker inspect "$IMAGE" > image-info.json
docker image ls "$IMAGE" --format '{{.Size}}' > image-size.txt

# 2. Dynamic port smoke test
FREE_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

echo "Testing on dynamic port: $FREE_PORT"
docker run -d --name smoke-test -p "$FREE_PORT:80" "$IMAGE"
sleep 3

# Health checks
curl -f "http://localhost:$FREE_PORT/" > smoke-test.html || exit 1
curl -f "http://localhost:$FREE_PORT/" -I  # Headers

# Cleanup
docker stop smoke-test
docker rm smoke-test

echo "Image validation complete"
echo "Artifacts: image-info.json, image-size.txt, smoke-test.html"
