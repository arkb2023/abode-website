#!/bin/bash
set -e

# Purpose: Test Docker image - verify files and healthcheck service
# Usage: 
#   ./scripts/test.sh <TEST_USER> <TEST_HOST> <IMAGE> [MAX_ATTEMPTS] [SLEEP_INTERVAL] [TEST_PORT]

TEST_USER="${1}"
TEST_HOST="${2}"
IMAGE="${3}"
MAX_ATTEMPTS="${4:-10}"
SLEEP_INTERVAL="${5:-3}"
TEST_PORT="${6:-9081}"

echo "════════════════════════════════════════════════"
echo "Running Tests on Test server"
echo "════════════════════════════════════════════════"
echo "Target: ${TEST_USER}@${TEST_HOST}"
echo "Image: ${IMAGE}"
echo "Healthcheck attempts: ${MAX_ATTEMPTS}"
echo "Sleep interval: ${SLEEP_INTERVAL}s"
echo ""

ssh -o StrictHostKeyChecking=no ${TEST_USER}@${TEST_HOST} << REMOTE_TEST_EOF
  set -e
  docker rm -f test-web 2>/dev/null || true
  docker image prune -f --filter "until=2h"

  # Create test directories
  mkdir -p /var/lib/test-artifacts /var/log/test-runner /tmp/test-logs
  
  # Start timing
  START_TIME=\$(date +%s)
  
  # Run the actual test logic
  IMAGE="${IMAGE}"
  MAX_ATTEMPTS="${MAX_ATTEMPTS}"
  SLEEP_INTERVAL="${SLEEP_INTERVAL}"
  TEST_PORT="${TEST_PORT}"
  
  # [ALL THE EXISTING TEST LOGIC GOES HERE - Copy from your current test.sh]
  
  # Validate arguments
  if [ -z "\$IMAGE" ]; then
    echo "Usage: \$0 <IMAGE> [MAX_ATTEMPTS] [SLEEP_INTERVAL] [TEST_PORT]"
    exit 1
  fi
  
  echo "════════════════════════════════════════════════"
  echo "Testing Docker Image on ${TEST_HOST} server"
  echo "════════════════════════════════════════════════"
  echo "Image: \${IMAGE}"
  echo "Healthcheck attempts: \${MAX_ATTEMPTS}"
  echo "Sleep interval: \${SLEEP_INTERVAL}s"
  echo ""

  # Cleanup any previous test container
  echo "Cleaning up previous test containers..."
  docker rm -f test-web 2>/dev/null || true
  echo "Cleanup done"
  echo ""

  # Pull latest image
  echo "Pulling image from Docker Hub..."
  echo "   Image: \${IMAGE}"
  docker pull \${IMAGE} || {
    echo "Failed to pull image"
    exit 1
  }
  echo "Image pulled successfully"
  echo ""

  # Verify files in image
  echo "Verifying files in image..."
  echo "   Listing /var/www/html/:"
  docker run --rm \${IMAGE} ls -la /var/www/html/ || {
    echo "Failed to list directory"
    exit 1
  }
  echo ""
  
  echo "   Checking index.html..."
  docker run --rm \${IMAGE} test -f /var/www/html/index.html || {
    echo "index.html not found"
    exit 1
  }
  echo "index.html found"
  echo ""
  
  echo "   Checking images/github3.jpg..."
  docker run --rm \${IMAGE} test -f /var/www/html/images/github3.jpg || {
    echo "images/github3.jpg not found"
    exit 1
  }
  echo "images/github3.jpg found"
  echo ""
  
  # Start test container with longer startup buffer
  echo "Starting test container..."
  docker run -d --name test-web -p \${TEST_PORT}:80 \${IMAGE} > /dev/null || {
    echo "Failed to start test container"
    exit 1
  }
  TEST_CONTAINER_ID=\$(docker ps --filter "name=test-web" -q)
  echo "Test container started: \${TEST_CONTAINER_ID}"
  echo ""
  
  # Check if container is still running immediately
  sleep 2
  if ! docker ps --filter "name=test-web" --quiet | grep -q . 2>/dev/null; then
    echo "Container exited immediately after startup"
    echo ""
    echo "Container logs:"
    docker logs test-web 2>/dev/null || true
    echo ""
    echo "Debugging info:"
    echo "   Checking if port 80 is already bound on host:"
    netstat -tuln | grep ":80 " || echo "   (port 80 not listening)"
    echo ""
    echo "Cleaning up..."
    docker rm -f test-web 2>/dev/null || true
    exit 1
  fi
  echo ""
  
  # Initial wait for service startup (Apache needs time)
  echo "Waiting for service to start (initial 5s buffer)..."
  sleep 5
  echo "   Starting healthcheck probes..."
  echo ""
  
  # Healthcheck with retry loop
  echo "Running healthcheck (max \${MAX_ATTEMPTS} attempts, \${SLEEP_INTERVAL}s interval)..."
  HEALTHCHECK_PASSED=0
  ATTEMPT_COUNT=0
  
  for i in \$(seq 1 \$MAX_ATTEMPTS); do
    ATTEMPT_COUNT=\$i
    sleep \${SLEEP_INTERVAL}
    
    # Debug: Check container status
    if ! docker ps --filter "name=test-web" --quiet | grep -q . 2>/dev/null; then
      echo "Container crashed/exited"
      echo ""
      echo "Container logs:"
      docker logs test-web 2>/dev/null || true
      echo ""
      echo "Cleaning up..."
      docker rm -f test-web 2>/dev/null || true
      exit 1
    fi
    
    # Debug: Check port binding
    PORT_CHECK=\$(docker port test-web 80/tcp 2>/dev/null || echo "not_bound")
    
    # Try curl with verbose on failure
    if curl -f -s http://localhost:\${TEST_PORT}/ > /dev/null 2>&1; then
      echo "Healthcheck PASSED on attempt \$i"
      HEALTHCHECK_PASSED=1
      break
    fi
    
    # Show debug info on every 3rd attempt
    if [ \$((i % 3)) -eq 0 ]; then
      echo "   [Debug] Attempt \$i - Port binding: \$PORT_CHECK"
      echo "   [Debug] Container still running: \$(docker ps --filter 'name=test-web' -q)"
    fi
    
    echo "Attempt \$i/\${MAX_ATTEMPTS} failed, retrying..."
  done
  
  if [ "\$HEALTHCHECK_PASSED" != "1" ]; then
    echo "Healthcheck failed after \$ATTEMPT_COUNT attempts"
    echo ""
    echo "Container info:"
    docker ps -a --filter "name=test-web" || true
    echo ""
    echo "Port binding:"
    docker port test-web 2>/dev/null || echo "   (not available)"
    echo ""
    echo "Container logs (last 50 lines):"
    docker logs test-web 2>/dev/null | tail -50 || true
    echo ""
    echo "Network diagnostics from host:"
    echo "   Checking if port \${TEST_PORT} is listening:"
    netstat -tuln | grep \${TEST_PORT} || echo "   (port \${TEST_PORT} not listening on host)"
    echo ""
    echo "Cleaning up..."
    docker stop test-web 2>/dev/null || true
    docker rm -f test-web 2>/dev/null || true
    exit 1
  fi
  echo ""
  
  # Final smoke test
  echo "Running final smoke test..."
  echo "   Fetching http://localhost:\${TEST_PORT}/..."
  HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:\${TEST_PORT}/)
  if [ "\$HTTP_CODE" -eq 200 ]; then
    echo "HTTP 200 OK"
  else
    echo "Unexpected HTTP status: \$HTTP_CODE"
    exit 1
  fi
  echo ""
  
  echo "Response preview:"
  curl -s http://localhost:\${TEST_PORT}/ | head -15
  echo ""
  
  # Cleanup test container
  echo "Cleaning up test container..."
  docker stop test-web 2>/dev/null || true
  docker rm -f test-web 2>/dev/null || true
  docker image prune -f --filter "dangling=true"
  echo "Cleanup done"
  echo ""


  # Save test results
  mkdir -p /var/lib/test-artifacts
  cp /tmp/test-output.log /var/lib/test-artifacts/test-\$(date +%Y%m%d-%H%M%S).log 2>/dev/null || true
  
  echo "════════════════════════════════════════════════"
  echo "Test stage completed successfully"
  echo "Test logs saved to /var/lib/test-artifacts/"
  echo "Total time: \$((\$(date +%s) - \$START_TIME))s"
  echo "════════════════════════════════════════════════"

REMOTE_TEST_EOF

# Exit with SSH command status
TEST_STATUS=$?

if [ $TEST_STATUS -eq 0 ]; then
  echo ""
  echo "════════════════════════════════════════════════"
  echo "Test deployment successful"
  echo "Image: ${IMAGE}"
  echo "Endpoint: http://${TEST_HOST}"
  echo "════════════════════════════════════════════════"
else
  echo ""
  echo "Test deployment failed (exit code: $TEST_STATUS)"
  exit 1
fi
