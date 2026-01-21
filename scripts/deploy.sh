#!/bin/bash
set -e

# Purpose: Deploy image to production via SSH
# Usage: ./scripts/deploy.sh <PROD_USER> <PROD_HOST> <IMAGE>
# Ex: 
# ./scripts/deploy.sh ubuntu <prod-instance> arkb2023/abode-website:v1.0-test

PROD_USER="${1}"
PROD_HOST="${2}"
IMAGE="${3}"

# Validate arguments
if [ -z "$PROD_USER" ] || [ -z "$PROD_HOST" ] || [ -z "$IMAGE" ]; then
  echo "Usage: $0 <PROD_USER> <PROD_HOST> <IMAGE>"
  exit 1
fi

echo "════════════════════════════════════════════════"
echo "Deploying to Production"
echo "════════════════════════════════════════════════"
echo "Target: ${PROD_USER}@${PROD_HOST}"
echo "Image: ${IMAGE}"
echo ""

# Execute remote deployment via SSH
echo "Connecting to prod server..."
echo ""

ssh -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_HOST} << DEPLOY_EOF
  set -e
  
  IMAGE="${IMAGE}"
  CONTAINER_NAME="webapp"
  PORT="80"
  
  echo "════════════════════════════════════════════════"
  echo "Remote Deployment Started"
  echo "════════════════════════════════════════════════"
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
  
  # Stop and remove old container (if exists)
  echo "Stopping old container (if exists)..."
  if docker ps --filter "name=\${CONTAINER_NAME}" --quiet | grep -q . 2>/dev/null; then
    docker stop \${CONTAINER_NAME} > /dev/null 2>&1 || true
    echo "   Container stopped"
  else
    echo "   No running container found"
  fi
  echo ""
  
  echo "Removing old container (if exists)..."
  if docker ps -a --filter "name=\${CONTAINER_NAME}" --quiet | grep -q . 2>/dev/null; then
    docker rm \${CONTAINER_NAME} > /dev/null 2>&1 || true
    echo "   Container removed"
  else
    echo "   No existing container found"
  fi
  echo ""
  
  # Start new container
  echo "Starting new container..."
  CONTAINER_ID=\$(docker run -d \\
    --name \${CONTAINER_NAME} \\
    -p \${PORT}:80 \\
    \${IMAGE})
  
  if [ -z "\$CONTAINER_ID" ]; then
    echo "Failed to start container"
    exit 1
  fi
  echo "Container started: \$CONTAINER_ID"
  echo ""
  
  # Verify container is running
  echo "Verifying deployment..."
  sleep 2
  
  if docker ps --filter "name=\${CONTAINER_NAME}" --quiet | grep -q . 2>/dev/null; then
    echo "Container is running"
    echo ""
    echo "Container details:"
    docker ps --filter "name=\${CONTAINER_NAME}"
  else
    echo "Container is not running"
    echo ""
    echo "Container logs:"
    docker logs \${CONTAINER_NAME} 2>/dev/null || true
    exit 1
  fi
  echo ""
  
  echo "════════════════════════════════════════════════"
  echo "Deployment completed successfully"
  echo "Service URL: http://${PROD_HOST}"
  echo "════════════════════════════════════════════════"
DEPLOY_EOF

# Exit with SSH command status
DEPLOY_STATUS=$?

if [ $DEPLOY_STATUS -eq 0 ]; then
  echo ""
  echo "════════════════════════════════════════════════"
  echo "Production deployment successful"
  echo "Image: ${IMAGE}"
  echo "Endpoint: http://${PROD_HOST}"
  echo "════════════════════════════════════════════════"
else
  echo ""
  echo "Production deployment failed (exit code: $DEPLOY_STATUS)"
  exit 1
fi
