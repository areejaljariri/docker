#!/bin/bash
set -e

echo "=== Step 1: Starting Green Environment (v2.0) ==="
docker compose up -d app-green

echo "=== Step 2: Running Smoke Test on Green (Port 8081) ==="
MAX_RETRIES=5
COUNT=0

while [ $COUNT -lt $MAX_RETRIES ]; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 || true)
  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "SUCCESS: Green environment is healthy!"
    break
  fi
  echo "Waiting for Green environment... Attempt $((COUNT+1))/$MAX_RETRIES"
  sleep 2
  COUNT=$((COUNT+1))
done

if [ $COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Smoke test failed on Green! Rolling back..."
  docker compose stop app-green
  exit 1
fi

echo "=== Step 3: Switching Proxy Routing to Green ==="
cat <<EOF > nginx.conf
server {
    listen 80;

    location / {
        proxy_pass http://app-green:80;
    }
}
EOF

docker compose exec -T proxy nginx -s reload

echo "=== Step 4: Shutting Down Blue Environment ==="
docker compose stop app-blue

echo "=== Blue-Green Deployment Completed Successfully! ==="
