#!/bin/bash
set -e

CURRENT_VERSION="v3"
NEW_VERSION="v4"
TIMEOUT=60
SERVICES=("api" "worker" "frontend")
IMAGE_PREFIX="job-tracker"
NETWORK="api_worker_frontend"

echo "🚀 Deploying $NEW_VERSION (previous: $CURRENT_VERSION)"

# Ensure network exists
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

# STARTING REDIS
if docker ps -a --format '{{.Names}}' | grep -q "^$IMAGE_PREFIX-redis$"; then
  echo "🔁 Redis exists — starting if stopped"
  docker start "$IMAGE_PREFIX-redis" >/dev/null 2>&1 || true
else
  echo "🚀 Starting Redis"
  docker run -d \
    --name "$IMAGE_PREFIX-redis" \
    --restart unless-stopped \
    -p 6379:6379 \
    --network "$NETWORK" \
    redis:7
fi

# Build images
for SERVICE in "${SERVICES[@]}"; do
  echo "🔨 Building $SERVICE:$NEW_VERSION"
  docker build -t "$IMAGE_PREFIX-$SERVICE:$NEW_VERSION" --no-cache ./$SERVICE
done

# Track containers
NEW_CONTAINERS=()

# ---------------------------
# START ALL NEW CONTAINERS
# ---------------------------
for SERVICE in "${SERVICES[@]}"; do
  echo "🔄 Starting $SERVICE..."

  CONTAINER_NAME="$IMAGE_PREFIX-$SERVICE-$NEW_VERSION"

  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK" \
    -e REDIS_HOST=job-tracker-redis \
    -e APP_ENV=production \
    -e APP_URL=147.93.28.195 \
    "$IMAGE_PREFIX-$SERVICE:$NEW_VERSION"

  NEW_CONTAINERS+=("$CONTAINER_NAME")
done

# ---------------------------
# HEALTH CHECK ALL
# ---------------------------
ALL_HEALTHY=true

for SERVICE in "${SERVICES[@]}"; do
  CONTAINER_NAME="$IMAGE_PREFIX-$SERVICE-$NEW_VERSION"

  echo "⏳ Checking $SERVICE..."

  TIMER=0
  while [ $TIMER -lt $TIMEOUT ]; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "starting")

    if [ "$STATUS" = "healthy" ]; then
      echo "✅ $SERVICE is healthy"
      break
    fi

    echo "[$SERVICE] $STATUS ($TIMER/$TIMEOUT)"
    sleep 5
    TIMER=$((TIMER + 5))
  done

  if [ $TIMER -ge $TIMEOUT ]; then
    echo "❌ $SERVICE failed health check"
    ALL_HEALTHY=false
  fi
done

# ---------------------------
# DECISION PHASE
# ---------------------------
if [ "$ALL_HEALTHY" = true ]; then
  echo "🎉 All services healthy — switching traffic"

  # remove old containers ONLY now
  for SERVICE in "${SERVICES[@]}"; do
    OLD_CONTAINER="$IMAGE_PREFIX-$SERVICE-$CURRENT_VERSION"
    docker rm -f "$OLD_CONTAINER" 2>/dev/null || true
  done

  echo "✅ Old version removed successfully"

else
  echo "❌ Rollback triggered — removing NEW containers"

  for CONTAINER in "${NEW_CONTAINERS[@]}"; do
    docker rm -f "$CONTAINER" 2>/dev/null || true
  done

  echo "🧹 New version removed, old version preserved"
  exit 1
fi

echo "🎉 Deployment complete: $NEW_VERSION"
