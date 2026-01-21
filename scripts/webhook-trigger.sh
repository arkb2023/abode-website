#!/bin/bash

# Purpose: Emulate GitHub webhook triggers for Jenkins pipeline testing
# Usage: 
#   chmod +x scripts/webhook-trigger.sh
#   ./scripts/webhook-trigger.sh [BRANCH]
# Example:
#   Trigger main branch (Build → Test → Deploy)
#   ./scripts/webhook-trigger.sh main
#   Trigger develop branch (Build → Test only)
#   ./scripts/webhook-trigger.sh develop
# Trigger staging branch
#   ./scripts/webhook-trigger.sh staging
# Trigger custom feature branch
#   ./scripts/webhook-trigger.sh feature/my-feature

set -e

# Get config
if [ ! -f "config.properties" ]; then
  echo "Error: config.properties not found in current directory"
  exit 1
fi

# Read config file
JENKINS_HOST=$(grep "^JENKINS_HOST=" config.properties 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
JENKINS_TOKEN=$(grep "^JENKINS_TOKEN=" config.properties 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
GITHUB_REPO=$(grep "^GITHUB_REPO=" config.properties 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
WEBHOOK_ENDPOINT=$(grep "^WEBHOOK_ENDPOINT=" config.properties 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

# Defaults if not in config
JENKINS_HOST="${JENKINS_HOST:-10.158.148.28:8080}"
WEBHOOK_ENDPOINT="${WEBHOOK_ENDPOINT:-/generic-webhook-trigger/invoke}"
GITHUB_REPO="${GITHUB_REPO:-arkb2023/abode-website}"

# Check required config
if [ -z "$JENKINS_TOKEN" ]; then
  echo "Error: JENKINS_TOKEN not found in config.properties"
  echo "   Add this line to config.properties:"
  echo "   JENKINS_TOKEN=webhook-abode"
  exit 1
fi

# Default branch if not provided
BRANCH="${1}"

# Function to display menu
show_menu() {
  echo ""
  echo "════════════════════════════════════════════════"
  echo "GitHub Webhook Trigger Emulator"
  echo "════════════════════════════════════════════════"
  echo "Select branch to trigger webhook:"
  echo ""
  echo "  1) main        (Build → Test → Deploy to Prod)"
  echo "  2) develop     (Build → Test only)"
  echo "  3) staging     (Build → Test only)"
  echo "  4) Custom branch"
  echo "  5) Exit"
  echo ""
}

# Function to get branch name
get_branch() {
  local choice="$1"
  
  case "$choice" in
    1)
      echo "refs/heads/main"
      ;;
    2)
      echo "refs/heads/develop"
      ;;
    3)
      echo "refs/heads/staging"
      ;;
    4)
      read -p "Enter branch name (without 'refs/heads/'): " custom_branch
      if [ -z "$custom_branch" ]; then
        echo "Branch name cannot be empty"
        exit 1
      fi
      echo "refs/heads/$custom_branch"
      ;;
    *)
      echo "invalid"
      ;;
  esac
}

# Function to send webhook
send_webhook() {
  local branch="$1"
  local short_branch=$(echo "$branch" | sed 's/refs\/heads\///')
  
  echo "════════════════════════════════════════════════"
  echo "Sending Webhook Trigger"
  echo "════════════════════════════════════════════════"
  echo " Jenkins Host: http://${JENKINS_HOST}"
  echo " Token: ${JENKINS_TOKEN}"
  echo " Repository: ${GITHUB_REPO}"
  echo " Branch: ${short_branch}"
  echo " Endpoint: ${WEBHOOK_ENDPOINT}"
  echo ""
  
  # Construct webhook URL
  WEBHOOK_URL="http://${JENKINS_HOST}${WEBHOOK_ENDPOINT}?token=${JENKINS_TOKEN}"
  
  # Construct payload
  PAYLOAD=$(cat <<EOF
{
  "ref": "${branch}",
  "repository": {
    "full_name": "${GITHUB_REPO}"
  },
  "pusher": {
    "name": "test-user"
  }
}
EOF
)
  
  echo "Payload:"
  echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
  echo ""
  
  echo "Sending webhook..."
  
  # Send webhook
  RESPONSE=$(curl -s -X POST "${WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  echo ""
  echo "Webhook sent successfully!"
  echo ""
  echo "Response:"
  echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
  echo ""
  
  # Parse response for triggered status
  if echo "$RESPONSE" | grep -q '"triggered":true'; then
    echo "════════════════════════════════════════════════"
    echo "Build queued successfully!"
    echo "════════════════════════════════════════════════"
    echo ""
    echo "Expected Pipeline Flow:"
    if [ "$short_branch" = "main" ]; then
      echo "   Stage 1: Build Docker image"
      echo "   Stage 2: Test (healthcheck + smoke test)"
      echo "   Stage 3: Deploy to Production"
    else
      echo "   Stage 1: Build Docker image"
      echo "   Stage 2: Test (healthcheck + smoke test)"
      echo "   (Deploy skipped - not main branch)"
    fi
    echo ""
    echo "Monitor at: http://${JENKINS_HOST}/job/abode-website-main-gwt/"
    echo ""
  elif echo "$RESPONSE" | grep -q '"triggered":false'; then
    echo "Warning: Webhook received but did not trigger"
    echo "Check Jenkins logs for details"
    echo ""
  else
    echo "Could not determine trigger status from response"
    echo ""
  fi
}

# Interactive mode if no branch provided
if [ -z "$BRANCH" ]; then
  while true; do
    show_menu
    read -p "Enter choice [1-5]: " choice
    
    case "$choice" in
      5)
        echo "Exiting"
        exit 0
        ;;
      *)
        BRANCH=$(get_branch "$choice")
        if [ "$BRANCH" != "invalid" ]; then
          send_webhook "$BRANCH"
          read -p "Press Enter to continue..."
        else
          echo "Invalid choice. Please try again."
          sleep 1
        fi
        ;;
    esac
  done
else
  # Non-interactive mode - branch provided as argument
  # Normalize branch name
  if [[ "$BRANCH" == "refs/heads/"* ]]; then
    # Already in full format
    FULL_BRANCH="$BRANCH"
  else
    # Convert short name to full ref
    FULL_BRANCH="refs/heads/$BRANCH"
  fi
  
  send_webhook "$FULL_BRANCH"
fi
