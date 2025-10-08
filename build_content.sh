#!/bin/bash
TARGET_ARCH=$(dpkg --print-architecture)
if [[ -n $1 ]]; then 
    TARGET_ARCH=$1 
fi
echo TARGET_ARCH: ${TARGET_ARCH}

IMAGE_NAME="systemd-greengrass"
IMAGE_TAG="latest"
DOCKER_CLI="docker"

echo "--- Building SystemD + Greengrass image ---"
${DOCKER_CLI} build --platform linux/${TARGET_ARCH} -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo "--- Creating docker-compose.env ---"
rm -f ./docker-compose/docker-compose.env
echo "IMAGE_NAME=${IMAGE_NAME}" >> ./docker-compose/docker-compose.env
echo "IMAGE_TAG=${IMAGE_TAG}" >> ./docker-compose/docker-compose.env

echo "--- Saving image to tar.gz ---"
rm -f ./docker-compose/*.tar.gz
${DOCKER_CLI} save ${IMAGE_NAME}:${IMAGE_TAG} | gzip > ./docker-compose/image.tar.gz

echo "--- Cleaning up local image ---"
${DOCKER_CLI} rmi ${IMAGE_NAME}:${IMAGE_TAG}

echo "--- Build complete ---"
