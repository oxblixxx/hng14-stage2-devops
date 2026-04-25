#!/bin/bash
set -e

CURRENT_VERSION="v1"
NEW_VERSION="v2"
TIMEOUT=60
SERVICES=("api" "worker" "frontend")
IMAGE_PREFIX="job-tracker"
NETWORK="api_worker_frontend"

echo "🚀 Deploying $NEW_VERSION (previous: $CURRENT_VERSION)"

# Ensure network exists
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

echo "bring up redis"
docker compose up redis -d

# Build images
for SERVICE in "${SERVICES[@]}"; do
  echo "🔨 Building $SERVICE:$NEW_VERSION"
  docker build -t "$IMAGE_PREFIX-$SERVICE:$NEW_VERSION" --no-cache ./$SERVICE
done

# Deploy services
for SERVICE in "${SERVICES[@]}"; do
  echo "🔄 Rolling $SERVICE..."

  # Update env version safely
  sed -i "s/^VERSION=.*/VERSION=$NEW_VERSION/" .env

  # Correct container name (NO colon allowed)
  CONTAINER_NAME="$IMAGE_PREFIX-$SERVICE-$NEW_VERSION"

  # Run new container
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK" \
    "$IMAGE_PREFIX-$SERVICE:$NEW_VERSION"

  NEW_CONTAINER="$CONTAINER_NAME"

  # Health check loop
  TIMER=0
  while [ $TIMER -lt $TIMEOUT ]; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$NEW_CONTAINER" 2>/dev/null || echo "starting")

    if [ "$STATUS" = "healthy" ]; then
      echo "✅ $SERVICE $NEW_VERSION is healthy"

      # Stop old container (if exists)
      OLD_CONTAINER="$IMAGE_PREFIX-$SERVICE-$CURRENT_VERSION"
      docker rm -f "$OLD_CONTAINER" 2>/dev/null || true

      break
    fi

    echo "[$SERVICE] $STATUS ($TIMER/$TIMEOUT)"
    sleep 5
    TIMER=$((TIMER + 5))
  done

  # Rollback if failed
  if [ $TIMER -ge $TIMEOUT ]; then
    echo "❌ $SERVICE failed health check. Rolling back..."

    docker rm -f "$NEW_CONTAINER" 2>/dev/null || true
    exit 1
  fi
done

echo "🎉 Deployment complete: $NEW_VERSION"
