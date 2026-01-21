#!/bin/bash
set -e

# Purpose: Build Docker image and push to Docker Hub
# Usage: ./scripts/build.sh <DOCKER_HUB_USER> <IMAGE_NAME> <BUILD_TAG> <DOCKER_USER> <DOCKER_PASS>
# Ex:
# ./scripts/build.sh arkb2023 abode-website v1.0-test $DOCKER_USER $DOCKER_PASS

DOCKER_HUB_USER="${1}"
IMAGE_NAME="${2}"
BUILD_TAG="${3}"
DOCKER_USER="${4}"
DOCKER_PASS="${5}"

# Validate arguments
if [ -z "$DOCKER_HUB_USER" ] || [ -z "$IMAGE_NAME" ] || [ -z "$BUILD_TAG" ]; then
  echo "Usage: $0 <DOCKER_HUB_USER> <IMAGE_NAME> <BUILD_TAG> <DOCKER_USER> <DOCKER_PASS>"
  exit 1
fi

IMAGE="${DOCKER_HUB_USER}/${IMAGE_NAME}:${BUILD_TAG}"

echo "════════════════════════════════════════════════"
echo "Building Docker Image"
echo "════════════════════════════════════════════════"
echo "Image: ${IMAGE}"
echo "Context: $(pwd)"
echo ""

# Build image
echo "Building image..."
docker build -t ${IMAGE} . || {
  echo "Docker build failed"
  exit 1
}
echo "Image built successfully"
echo ""

# Login to Docker Hub
echo "Authenticating to Docker Hub..."
echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin > /dev/null 2>&1 || {
  echo "Docker login failed"
  exit 1
}
echo "Logged in successfully"
echo ""

# Push to Docker Hub
echo "Pushing image to Docker Hub..."
docker push ${IMAGE} || {
  echo "Docker push failed"
  exit 1
}
echo "Image pushed successfully"
echo ""

# Logout for security
echo "Logging out from Docker Hub..."
docker logout > /dev/null 2>&1
echo "Logged out"
echo ""

echo "════════════════════════════════════════════════"
echo "Build stage completed successfully"
echo "Image: ${IMAGE}"
echo "════════════════════════════════════════════════"
