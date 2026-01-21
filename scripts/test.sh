#!/bin/bash
set -e

# Purpose: Test Docker image - verify files and healthcheck service
# Usage: ./scripts/test.sh <IMAGE> [MAX_ATTEMPTS] [SLEEP_INTERVAL]
# Ex:
# ./scripts/test.sh arkb2023/abode-website:v1.0-test

IMAGE="${1}"
MAX_ATTEMPTS="${2:-10}"
SLEEP_INTERVAL="${3:-3}"

# Validate arguments
if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <IMAGE> [MAX_ATTEMPTS] [SLEEP_INTERVAL]"
  exit 1
fi

echo "════════════════════════════════════════════════"
echo "Testing Docker Image"
echo "════════════════════════════════════════════════"
echo "Image: ${IMAGE}"
echo "Healthcheck attempts: ${MAX_ATTEMPTS}"
echo "Sleep interval: ${SLEEP_INTERVAL}s"
echo ""

# Cleanup any previous test container
echo "Cleaning up previous test containers..."
docker rm -f test-web 2>/dev/null || true
echo "Cleanup done"
echo ""

# Verify files in image
echo "Verifying files in image..."
echo "   Listing /var/www/html/:"
docker run --rm ${IMAGE} ls -la /var/www/html/ || {
  echo "Failed to list directory"
  exit 1
}
echo ""

echo "   Checking index.html..."
docker run --rm ${IMAGE} test -f /var/www/html/index.html || {
  echo "index.html not found"
  exit 1
}
echo "index.html found"
echo ""

echo "   Checking images/github3.jpg..."
docker run --rm ${IMAGE} test -f /var/www/html/images/github3.jpg || {
  echo "images/github3.jpg not found"
  exit 1
}
echo "images/github3.jpg found"
echo ""

# Start test container
echo "Starting test container..."
docker run -d --name test-web -p 8081:80 ${IMAGE} > /dev/null || {
  echo "Failed to start test container"
  exit 1
}
TEST_CONTAINER_ID=$(docker ps --filter "name=test-web" -q)
echo "Test container started: ${TEST_CONTAINER_ID}"
echo ""

# Healthcheck with retry loop
echo "Running healthcheck (max ${MAX_ATTEMPTS} attempts, ${SLEEP_INTERVAL}s interval)..."
HEALTHCHECK_PASSED=0

for i in $(seq 1 $MAX_ATTEMPTS); do
  sleep $SLEEP_INTERVAL
  
  if curl -f -s http://localhost:8081/ > /dev/null 2>&1; then
    echo "Healthcheck PASSED on attempt $i"
    HEALTHCHECK_PASSED=1
    break
  fi
  
  echo "Attempt $i/$MAX_ATTEMPTS failed, retrying..."
done

if [ "$HEALTHCHECK_PASSED" != "1" ]; then
  echo "Healthcheck failed after $MAX_ATTEMPTS attempts"
  echo ""
  echo "Container logs:"
  docker logs test-web 2>/dev/null || true
  echo ""
  echo "Cleaning up..."
  docker stop test-web 2>/dev/null || true
  docker rm test-web 2>/dev/null || true
  exit 1
fi
echo ""

# Final smoke test
echo "Running final smoke test..."
echo "   Fetching http://localhost:8081/..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/)
if [ "$HTTP_CODE" -eq 200 ]; then
  echo "HTTP 200 OK"
else
  echo "Unexpected HTTP status: $HTTP_CODE"
  exit 1
fi
echo ""

echo "Response preview:"
curl -s http://localhost:8081/ | head -15
echo ""

# Cleanup test container
echo "Cleaning up test container..."
docker stop test-web 2>/dev/null || true
docker rm test-web 2>/dev/null || true
echo "Cleanup done"
echo ""

echo "════════════════════════════════════════════════"
echo "Test stage completed successfully"
echo "════════════════════════════════════════════════"
