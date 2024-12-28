#!/bin/sh

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <registry_url> <repository> <tag>"
  echo "Example: $0 localhost:5000 my-repo my-tag"
  exit 1
fi

REGISTRY_URL=$1
REPOSITORY=$2
TAG=$3
REGISTRY_IMAGE_NAME=registry:2

if ! command -v jq &> /dev/null; then
  echo "jq is not installed. Installing jq..."
  if [ -x "$(command -v apt)" ]; then
    sudo apt update && sudo apt install -y jq
  elif [ -x "$(command -v dnf)" ]; then
    sudo dnf install -y jq
  else
    echo "Error: Package manager not found. Please install jq manually."
    exit 1
  fi
fi

DIGEST=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "http://${REGISTRY_URL}/v2/${REPOSITORY}/manifests/${TAG}" \
  | jq -r '.config.digest')

if [ -z "$DIGEST" ] || [ "$DIGEST" == "null" ]; then
  echo "Error: Failed to retrieve digest for ${REPOSITORY}:${TAG}"
  exit 1
fi

echo "Digest for ${REPOSITORY}:${TAG} is ${DIGEST}"

curl -X DELETE "http://${REGISTRY_URL}/v2/${REPOSITORY}/manifests/${DIGEST}"

if [ $? -eq 0 ]; then
  echo "Image ${REPOSITORY}:${TAG} deleted successfully from ${REGISTRY_URL}"
else
  echo "Error: Failed to delete image ${REPOSITORY}:${TAG}"
  exit 1
fi

echo "Running garbage collection..."
REGISTRY_CONTAINER_NAME=$(docker ps --filter "ancestor=$REGISTRY_IMAGE_NAME" --format "{{.Names}}" | head -n 1)

if [ -z "$REGISTRY_CONTAINER_NAME" ]; then
  echo "Error: No running Docker Registry container found."
  exit 1
fi

docker exec "$REGISTRY_CONTAINER_NAME" bin/registry garbage-collect /etc/docker/registry/config.yml

if [ $? -eq 0 ]; then
  echo "Garbage collection completed successfully."
else
  echo "Error: Garbage collection failed."
  exit 1
fi
